import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
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
  String _selectedCollection = 'Uncategorized';

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
        if (!_collections.contains(_selectedCollection)) {
          _selectedCollection = _collections.isNotEmpty ? _collections.first : 'Uncategorized';
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

      setState(() {
        _candidates
          ..clear()
          ..addAll(newOnes);
        _isBusy = false;
        _statusMessage = '${newOnes.length} file(s) ready to import';
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _statusMessage = 'Something went wrong: $e';
      });
    }
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

      var copied = 0;
      for (final c in selected) {
        if (mounted) {
          setState(() => _statusMessage = 'Copying ${copied + 1} of ${selected.length}: ${c.name}');
        }
        final title = p.basenameWithoutExtension(c.name);
        final ext = p.extension(c.name);
        final permanentPath = p.join(importDir.path, '${const Uuid().v4()}$ext');
        await File(c.path).copy(permanentPath);
        copied++;

        final audio = AudioFile(
          path: permanentPath,
          title: title,
          duration: Duration.zero,
          collection: _selectedCollection,
        );
        await storage.addAudioFile(audio);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${selected.length} file(s)')),
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
                  'Tap the button below. Then go to the folder where your scripture MP3s are and select the ones you want (you can select many at once).',
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
                          labelText: 'Save to collection',
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
                Text(
                  'All files you pick below go into this one collection - good for keeping '
                  'different Bible versions separate. Repeat this screen once per version.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _pickFiles,
                    icon: const Icon(Icons.folder_open, size: 30),
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
                      subtitle: Text(c.sizeLabel),
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
