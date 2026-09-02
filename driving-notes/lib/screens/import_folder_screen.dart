import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/folder_tree.dart';
import '../services/mp3_catalog.dart';
import '../services/simple_storage.dart';

/// Lets the user pick one or more MP3 files (from any folder)
/// and import them into the app library.
///
/// On Android this opens the system file picker.
/// You can navigate to your MP3 folder and select multiple files.
class ImportFolderScreen extends ConsumerStatefulWidget {
  const ImportFolderScreen({super.key});

  @override
  ConsumerState<ImportFolderScreen> createState() => _ImportFolderScreenState();
}

class _ImportFolderScreenState extends ConsumerState<ImportFolderScreen> {
  final List<_Mp3Candidate> _candidates = [];
  bool _isBusy = false;
  String? _statusMessage;

  // Which "folder" all the files picked in this session get saved into -
  // e.g. "ESV Dramatized" for one batch, "NIV Narrated" for another.
  List<String> _collections = ['Uncategorized'];
  String _selectedCollection = 'King James Version';
  bool _autoSort = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    // Belt-and-suspenders on top of SimpleStorage's own SafeJson recovery:
    // this screen should never crash the whole app just because its
    // collection-name dropdown couldn't populate. Worst case it falls back
    // to the one default collection instead of taking the user down with it.
    List<String> names;
    try {
      names = await SimpleStorage().loadCollectionNames();
    } catch (e) {
      names = const ['Uncategorized'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read collections. ($e)')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _collections = names;
        final roots = <String>{
          ...SimpleStorage.defaultTranslationFolders,
          ...names.where((n) => !n.contains('/')),
        }.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _collections = roots.isNotEmpty ? roots : names;
        if (!_collections.contains(_selectedCollection)) {
          _selectedCollection = _collections.contains('King James Version')
              ? 'King James Version'
              : (_collections.isNotEmpty ? _collections.first : 'Uncategorized');
        }
      });
    }
  }

  Future<void> _promptNewCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. ESV Dramatized, NIV Narrated'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await SimpleStorage().addCollectionName(name);
      await _loadCollections();
      if (mounted) setState(() => _selectedCollection = name);
    }
  }

  /// Opens the phone's normal file picker.
  /// User can go to any folder and select multiple MP3s.
  Future<void> _pickFiles() async {
    setState(() {
      _isBusy = true;
      _statusMessage = 'Opening file picker…';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'mp4'],
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isBusy = false;
          _statusMessage = 'No files selected.';
        });
        return;
      }

      final newOnes = <_Mp3Candidate>[];
      for (final f in result.files) {
        if (f.path == null) continue;
        newOnes.add(_Mp3Candidate(
          name: f.name,
          path: f.path!,
          sizeLabel: _formatSize(f.size),
          selected: true,
        ));
      }

      _showCandidates(newOnes, 'Selected ${newOnes.length} file(s)');
    } catch (e) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Something went wrong: $e';
      });
    }
  }

  static const _audioExtensions = {'.mp3', '.m4a', '.wav', '.aac', '.ogg', '.mp4'};

  /// Pick one folder on the tablet (KJV, David, the whole dump) and take
  /// every audio file in it, including files inside Matthew, Genesis, etc.
  Future<void> _pickFolder() async {
    setState(() {
      _isBusy = true;
      _statusMessage = 'Opening folder picker…';
    });

    try {
      await _askToReadMusic();
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) {
        setState(() {
          _isBusy = false;
          _statusMessage = 'No folder selected.';
        });
        return;
      }

      setState(() => _statusMessage = 'Scanning $dirPath …');
      final roots = await _folderRootsToScan(dirPath);
      final found = <_Mp3Candidate>[];
      final seen = <String>{};
      for (final root in roots) {
        await _collectAudio(Directory(root), found, seen);
      }
      found.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (found.isEmpty) {
        final fallback = await _scanKnownMusicDirs(preferName: p.basename(dirPath));
        if (fallback.isNotEmpty) {
          fallback.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          await _offerBulkImport(fallback, p.basename(dirPath));
          return;
        }
        setState(() {
          _isBusy = false;
          _statusMessage =
              'Android would not list MP3s in $dirPath. Copy C:\\music onto the tablet under Music, then tap Scan tablet Music.';
        });
        return;
      }
      await _offerBulkImport(found, p.basename(dirPath));
    } catch (e) {
      setState(() {
        _isBusy = false;
        _statusMessage =
            'Could not read that folder ($e). If Android blocked it, copy the folder onto the tablet storage and pick it again, or use Choose MP3 Files.';
      });
    }
  }


  Future<List<String>> _volumeRoots() async {
    final roots = <String>{
      '/storage/emulated/0',
      '/sdcard',
    };
    try {
      final storage = Directory('/storage');
      if (await storage.exists()) {
        await for (final entity in storage.list(followLinks: false)) {
          if (entity is! Directory) continue;
          final name = p.basename(entity.path);
          if (name == 'emulated' || name == 'self' || name.startsWith('.')) continue;
          roots.add(entity.path);
        }
      }
    } catch (_) {}
    return roots.toList();
  }

  Future<void> _askToReadMusic() async {
    try {
      await Permission.audio.request();
    } catch (_) {}
    try {
      await Permission.storage.request();
    } catch (_) {}
  }

  Future<List<String>> _folderRootsToScan(String picked) async {
    final roots = <String>{};
    if (picked.trim().isNotEmpty) roots.add(picked.trim());

    final name = p.basename(picked);
    final volumes = await _volumeRoots();
    final extras = ['', 'Documents', 'Download', 'Music', 'music'];
    final bases = <String>[];
    for (final vol in volumes) {
      for (final extra in extras) {
        bases.add(extra.isEmpty ? vol : p.join(vol, extra));
      }
    }
    for (final base in bases) {
      final direct = Directory(p.join(base, name));
      if (await direct.exists()) roots.add(direct.path);
    }
    return roots.toList();
  }

  Future<void> _collectAudio(Directory dir, List<_Mp3Candidate> out, Set<String> seen) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (!_audioExtensions.contains(ext)) continue;
          if (!seen.add(entity.path)) continue;
          final length = await entity.length();
          out.add(_Mp3Candidate(
            name: p.basename(entity.path),
            path: entity.path,
            sizeLabel: _formatSize(length),
            selected: true,
          ));
        } else if (entity is Directory) {
          await _collectAudio(entity, out, seen);
        }
      }
    } catch (_) {}
  }


  Future<void> _scanTabletMusic() async {
    setState(() {
      _isBusy = true;
      _statusMessage = 'Scanning Music on this tablet…';
    });
    final found = await _scanKnownMusicDirs();
    found.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (found.isEmpty) {
      setState(() {
        _isBusy = false;
        _statusMessage =
            'No MP3s under Music / Download. Copy C:\\music to the tablet Music folder, then try again.';
      });
      return;
    }
    await _offerBulkImport(found, 'Music');
  }

  Future<List<_Mp3Candidate>> _scanKnownMusicDirs({String? preferName}) async {
    final found = <_Mp3Candidate>[];
    final seen = <String>{};
    final volumes = await _volumeRoots();
    final extras = ['Music', 'music', 'Download', 'Documents', ''];
    for (final vol in volumes) {
      for (final extra in extras) {
        final base = extra.isEmpty ? vol : p.join(vol, extra);
        final root = preferName == null || preferName.isEmpty
            ? Directory(base)
            : Directory(p.join(base, preferName));
        if (await root.exists()) {
          await _collectAudio(root, found, seen);
        }
      }
    }
    return found;
  }

  List<_Mp3Candidate> _preferMp3(List<_Mp3Candidate> files) {
    final byStem = <String, _Mp3Candidate>{};
    for (final f in files) {
      final stem = p.basenameWithoutExtension(f.name).toLowerCase();
      final ext = p.extension(f.name).toLowerCase();
      final prev = byStem[stem];
      if (prev == null) {
        byStem[stem] = f;
        continue;
      }
      final prevExt = p.extension(prev.name).toLowerCase();
      if (ext == '.mp3' && prevExt != '.mp3') {
        byStem[stem] = f;
      }
    }
    return byStem.values.toList();
  }

  Future<void> _offerBulkImport(List<_Mp3Candidate> files, String label) async {
    files = _preferMp3(files);
    if (files.length >= 8 && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import ${files.length} files?'),
          content: Text(
            'From "$label". Files are sorted by folder and filename '
            '(BSB / Gilbert / 2 Samuel). Already-imported names are skipped. '
            'This can take several minutes.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Review list')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import all')),
          ],
        ),
      );
      if (go == true) {
        _candidates
          ..clear()
          ..addAll(files);
        await _importSelected();
        return;
      }
    }
    _showCandidates(files, '${files.length} file(s) from $label');
  }

  void _showCandidates(List<_Mp3Candidate> files, String status) {
    setState(() {
      _candidates
        ..clear()
        ..addAll(files);
      _isBusy = false;
      _statusMessage = status;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _toggle(int index) {
    setState(() {
      _candidates[index].selected = !_candidates[index].selected;
    });
  }

  Future<void> _importSelected() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tick at least one file')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage = 'Copying to app storage…';
    });

    final storage = SimpleStorage();

    try {
      // Files picked via the system file picker land in a TEMPORARY cache
      // folder (…/cache/file_picker/…) that Android can clear at any time -
      // that's exactly what was causing "Step 1 (convert to WAV) failed: no
      // output file was produced" when generating captions on a file that
      // had been sitting around for a while: the source file was simply
      // gone by the time Whisper went looking for it. Copying each file
      // into the app's own permanent storage at import time fixes that for
      // good (same folder pattern Recorded Readings already uses).
      final docs = await getApplicationDocumentsDirectory();
      final importDir = Directory(p.join(docs.path, 'imported_audio'));
      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }

      final existing = await storage.loadAudioFiles();
      final existingTitles = existing.map((f) => f.title.toLowerCase()).toSet();
      var copied = 0;
      var skipped = 0;
      for (final c in selected) {
        final title = p.basenameWithoutExtension(c.name);
        if (existingTitles.contains(title.toLowerCase())) {
          skipped++;
          continue;
        }
        if (mounted) {
          setState(() => _statusMessage = 'Copying ${copied + 1} of ${selected.length}: ${c.name}');
        }
        final ext = p.extension(c.name);
        final permanentPath = p.join(importDir.path, '${const Uuid().v4()}$ext');
        await File(c.path).copy(permanentPath);
        copied++;

        final guess = _autoSort
            ? Mp3Catalog.parsePath(c.path, translation: _selectedCollection)
            : CatalogGuess(
                title: title,
                translation: _selectedCollection,
                folderPath: _selectedCollection,
              );
        await storage.addCollectionName(guess.folderPath);
        if (guess.book != null) {
          await storage.addCollectionName(FolderTree.join(guess.translation, guess.book!));
        }

        final audio = AudioFile(
          path: permanentPath,
          title: title,
          duration: Duration.zero,
          collection: guess.folderPath,
          translation: guess.translation,
          narrator: guess.narrator ?? '',
        );
        await storage.addAudioFile(audio);
        existingTitles.add(title.toLowerCase());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $copied file(s)${skipped == 0 ? '' : ', skipped $skipped already in library'}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _candidates.where((c) => c.selected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import MP3s'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Samsung My Files can see the network share and SD card. This picker often cannot. Copy files onto the tablet or SD Music folder, then Scan tablet Music. In Choose Whole Folder tap the menu (three lines) and pick SD card if it is listed.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _collections.contains(_selectedCollection) ? _selectedCollection : null,
                        decoration: const InputDecoration(
                          labelText: 'Translation',
                          border: OutlineInputBorder(),
                        ),
                        items: _collections
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: _isBusy
                            ? null
                            : (v) {
                                if (v != null) setState(() => _selectedCollection = v);
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _isBusy ? null : _promptNewCollection,
                      icon: const Icon(Icons.create_new_folder),
                      tooltip: 'New collection',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sort into catalog'),
                  subtitle: const Text(
                    'Book and narrator come from the filename. '
                    'Job - Chapter 003 (Drama) goes to Translation / Job / Drama. '
                    '40Mat004 goes to Translation / Matthew.',
                  ),
                  value: _autoSort,
                  onChanged: _isBusy ? null : (v) => setState(() => _autoSort = v),
                ),
                Text(
                  _autoSort
                      ? 'Pick a pile of files. They land under the translation, then book, then reader.'
                      : 'All picked files go into the translation folder as-is.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _pickFolder,
                    icon: const Icon(Icons.folder, size: 30),
                    label: const Text('Choose Whole Folder'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _isBusy ? null : _scanTabletMusic,
                    icon: const Icon(Icons.library_music, size: 28),
                    label: const Text('Scan tablet Music'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickFiles,
                    icon: const Icon(Icons.audio_file, size: 28),
                    label: const Text('Choose MP3 Files'),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isBusy && _candidates.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_candidates.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No files chosen yet.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final c = _candidates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: CheckboxListTile(
                      value: c.selected,
                      onChanged: _isBusy ? null : (_) => _toggle(index),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      secondary: Icon(Icons.audiotrack, size: 34, color: theme.colorScheme.primary),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        _autoSort
                            ? '${c.sizeLabel}  →  ${FolderTree.displayPath(Mp3Catalog.parsePath(c.path, translation: _selectedCollection).folderPath)}'
                            : c.sizeLabel,
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  );
                },
              ),
            ),
          if (_candidates.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isBusy || selectedCount == 0) ? null : _importSelected,
                    icon: const Icon(Icons.file_download, size: 30),
                    label: Text(
                      selectedCount == 0
                          ? 'Select files first'
                          : 'Import $selectedCount file${selectedCount == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Mp3Candidate {
  final String name;
  final String path;
  final String sizeLabel;
  bool selected;

  _Mp3Candidate({
    required this.name,
    required this.path,
    required this.sizeLabel,
    this.selected = false,
  });
}

