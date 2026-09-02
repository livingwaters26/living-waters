import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/export_service.dart';
import '../services/folder_tree.dart';
import '../services/mp3_catalog.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import 'import_folder_screen.dart';
import 'record_reading_screen.dart';
import 'library_tree_screen.dart';
import 'sessions_screen.dart';

/// Reached from the "My MP3s" button on the home screen – list of
/// imported MP3 / audio files, grouped into collections.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _storage = SimpleStorage();
  final _transcripts = TranscriptService();
  final _export = ExportService();
  final _searchController = TextEditingController();
  List<AudioFile> _files = [];
  List<String> _allCollectionNames = [];
  bool _loading = true;

  // 'newest' | 'oldest' | 'title' | 'duration' - lets a long list be found
  // by typing a few letters and/or reordered without hunting through every
  // collection by hand.
  String _sortBy = 'newest';

  // 'name' | 'files' | 'recent' - which order the collection/folder cards
  // themselves appear in (separate from the file sort above, which only
  // orders files within a folder).
  String _collectionSortBy = 'name';

  // Tap "Select" in the app bar to check off several files and delete them
  // all in one go, instead of one at a time via each file's ⋮ menu.
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  /// Current library folder. Empty string is the top (computer-style root).
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<AudioFile> files = [];
    var collectionNames = <String>[];
    try {
      try {
        await _storage.ensureTranslationBookFolders();
      } catch (_) {}
      try {
        files = (await _storage.loadAudioFiles())
            .where((f) => !f.path.startsWith('tts:'))
            .toList();
      } catch (e) {
        files = [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not read the library list. ($e)')),
          );
        }
      }
      try {
        collectionNames = await _storage.loadCollectionNames();
      } catch (_) {
        collectionNames = [];
      }

    // Recover notes interrupted by crash / battery / phone call edge cases
    final incomplete = await _storage.findIncompleteNotes();
    if (incomplete.isNotEmpty) {
      final all = await _storage.loadNotes();
      for (var i = 0; i < all.length; i++) {
        if (!all[i].isComplete) {
          all[i] = all[i].copyWith(isComplete: true);
        }
      }
      await _storage.saveNotes(all);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovered ${incomplete.length} interrupted note(s)')),
        );
      }
    }

    } finally {
      if (mounted) {
        setState(() {
          _files = files;
          _allCollectionNames = collectionNames;
          _loading = false;
        });
      }
    }
  }

  /// Creates a subfolder inside the folder you are looking at, like a computer.
  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_currentPath.isEmpty ? 'New folder' : 'New folder in ${FolderTree.leafName(_currentPath)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
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
    if (name == null || name.isEmpty) return;
    if (name.contains('/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use New Folder again to go deeper. Do not type slashes.')),
        );
      }
      return;
    }

    final path = FolderTree.join(_currentPath, name);
    await _storage.addCollectionName(path);

    if (_currentPath.isEmpty) {
      final choice = await _askAddBibleBooks(name);
      if (choice != null) {
        await _storage.addBibleBookFolders(path, choice);
      }
    }

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${FolderTree.displayPath(path)}')),
      );
    }
  }

  Future<List<String>?> _askAddBibleBooks(String folderName) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bible book folders?'),
        content: Text(
          'Add a subfolder for each book under "$folderName"? '
          'Some Bibles include the Apocrypha.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, BibleTextService.bookOrder),
            child: const Text('66 books'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, BibleTextService.catholicBookOrder),
            child: const Text('With Apocrypha'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBibleBooksToFolder(String childName) async {
    final path = FolderTree.join(_currentPath, childName);
    final choice = await _askAddBibleBooks(childName);
    if (choice == null) return;
    await _storage.addBibleBookFolders(path, choice);
    await _load();
  }

  List<String> _knownFolderPaths() {
    final paths = <String>{..._allCollectionNames, ..._files.map((f) => f.collection)};
    return paths.map(FolderTree.normalize).where((p) => p.isNotEmpty).toList();
  }

  List<String> _childFoldersHere() {
    final order = _currentPath.isEmpty
        ? [...SimpleStorage.defaultTranslationFolders, 'Personal Readings']
        : BibleTextService.folderSortOrder;
    return FolderTree.childFolders(_knownFolderPaths(), _currentPath, preferredOrder: order);
  }

  List<AudioFile> _filesHere() {
    final here = FolderTree.normalize(_currentPath);
    final list = _files.where((f) => FolderTree.normalize(f.collection) == here).toList();
    list.sort((a, b) => Mp3Catalog.compareTitles(a.title, b.title));
    return list;
  }

  Future<void> _renameFolder(String childName) async {
    final oldPath = FolderTree.join(_currentPath, childName);
    final controller = TextEditingController(text: childName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == childName) return;
    if (name.contains('/')) return;
    await _storage.renameLibraryFolder(oldPath, FolderTree.join(_currentPath, name));
    await _load();
  }

  bool _folderIsEmpty(String childName) {
    final path = FolderTree.join(_currentPath, childName);
    final hasFiles = _files.any((f) => FolderTree.isUnder(f.collection, path));
    if (hasFiles) return false;
    return FolderTree.childFolders(_knownFolderPaths(), path).isEmpty;
  }

  Future<void> _deleteChildFolder(String childName) async {
    if (!_folderIsEmpty(childName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Move or delete what is inside this folder first.')),
        );
      }
      return;
    }
    await _deleteCollection(FolderTree.join(_currentPath, childName));
  }

  bool _goUpOrPop() {
    if (_currentPath.isNotEmpty) {
      setState(() => _currentPath = FolderTree.parentOf(_currentPath));
      return true;
    }
    return false;
  }

  /// Deletes an empty folder/collection. Only offered when a collection has
  /// zero files in it - a folder with files should be emptied (move or
  /// delete those files) before it can be removed, so this never silently
  /// takes recordings with it.
  Future<void> _deleteCollection(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this folder?'),
        content: Text('"$name" is empty. This just removes the folder itself - nothing to lose.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _storage.removeCollectionName(name);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "$name"')),
      );
    }
  }

  Future<void> _openImport() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ImportFolderScreen()),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _openRecordReading() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordReadingScreen()),
    );
    await _load();
  }

  /// Rename a file and/or move it to a different collection - the only way
  /// to fix these after the fact, since import only asks once up front.
  Future<void> _editFile(AudioFile file) async {
    final titleController = TextEditingController(text: file.title);
    var collections = await _storage.loadCollectionNames();
    if (!collections.contains(file.collection)) collections = [file.collection, ...collections];
    var selectedCollection = file.collection;

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Rename / move file'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title is just this file\'s name in the list. Collection is which '
                  'folder/section it shows up under (e.g. which Bible version).',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(dialogContext).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCollection,
                  decoration: const InputDecoration(labelText: 'Collection'),
                  items: [
                    ...collections.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    const DropdownMenuItem(value: '__new__', child: Text('+ New collection…')),
                  ],
                  onChanged: (v) async {
                    if (v == '__new__') {
                      final controller = TextEditingController();
                      final name = await showDialog<String>(
                        context: dialogContext,
                        builder: (context) => AlertDialog(
                          title: const Text('New collection'),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'e.g. ESV Dramatized'),
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
                        final path = name.contains('/') ? FolderTree.normalize(name) : FolderTree.join(_currentPath, name);
                        await _storage.addCollectionName(path);
                        collections = await _storage.loadCollectionNames();
                        setDialogState(() => selectedCollection = path);
                      }
                    } else if (v != null) {
                      setDialogState(() => selectedCollection = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final newTitle = titleController.text.trim();
    final updated = file.copyWith(
      title: newTitle.isEmpty ? file.title : newTitle,
      collection: selectedCollection,
    );
    await _storage.updateAudioFile(updated);
    await _load();
  }

  /// Shares/exports the actual audio file (not just the notes) out of the
  /// app - e.g. to email it to yourself, save it to Drive, or pull it into
  /// something like Audacity. Named after the file's title in the library
  /// (not a random ID) so it's obvious what it is once it lands somewhere
  /// else, and keeps its real extension (.m4a for an in-app recording).
  Future<void> _shareAudioFile(AudioFile file) async {
    final f = File(file.path);
    if (!await f.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that audio file on this device to share.'),
          ),
        );
      }
      return;
    }
    final fileName = _export.safeAudioFileName(file.title, file.path);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, name: fileName)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share this file: $e')),
        );
      }
    }
  }

  /// Shares every currently-selected file in one shot, so you can dump a
  /// whole batch of readings out to Drive/Downloads/etc. at once (e.g. to
  /// upload into an external tool like Adobe Podcast's Enhance Speech)
  /// instead of sharing one at a time. Android's share sheet accepts
  /// multiple files in a single share action.
  Future<void> _shareSelected() async {
    final selected = _files.where((f) => _selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) return;

    final xFiles = <XFile>[];
    final missing = <String>[];
    for (final file in selected) {
      if (await File(file.path).exists()) {
        xFiles.add(XFile(file.path, name: _export.safeAudioFileName(file.title, file.path)));
      } else {
        missing.add(file.title);
      }
    }

    if (xFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('None of the selected files could be found on this device.')),
        );
      }
      return;
    }

    try {
      await SharePlus.instance.share(ShareParams(files: xFiles));
      if (missing.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shared ${xFiles.length} file(s) - skipped ${missing.length} that couldn\'t be found.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share selected files: $e')),
        );
      }
    }
  }

  /// True only for files the app itself created (recordings) - never an
  /// imported MP3 living somewhere else on the device.
  Future<bool> _appOwnsFile(AudioFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.isWithin(docs.path, file.path);
  }

  Future<void> _deleteFile(AudioFile file) async {
    final ownsFile = await _appOwnsFile(file);
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this file?'),
        content: Text(
          '"${file.title}" and all its sessions and notes will be removed. '
          '${ownsFile ? 'The recording itself will be deleted too - this can\'t be undone.' : 'The original MP3 stays on your device - only removed from this library.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _storage.deleteAudioFile(file.id);
    await _transcripts.delete(file.id);

    if (ownsFile) {
      try {
        final f = File(file.path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Best effort - not worth blocking the library removal on this.
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${file.title}"')),
      );
    }
    await _load();
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return 'Unknown length';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _searching => _searchController.text.trim().isNotEmpty;

  /// Files matching the search box (by title), in the chosen sort order -
  /// the sort choice applies across the whole library, not per collection.
  List<AudioFile> get _visibleFiles {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<AudioFile>.from(_files)
        : _files.where((f) => f.title.toLowerCase().contains(q)).toList();
    switch (_sortBy) {
      case 'oldest':
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case 'title':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'duration':
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'newest':
      default:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }
    return list;
  }

  /// Groups the currently-visible (searched + sorted) files by their
  /// collection ("folder") for the list view - alphabetical by collection
  /// name. Includes collections that don't have any files yet (created
  /// ahead of time via the "New collection" button) so creating one is
  /// visibly confirmed here instead of seeming to do nothing - but only
  /// when not searching, so a search doesn't surface a wall of empty
  /// folders that don't match anything.
  Map<String, List<AudioFile>> _grouped() {
    final map = <String, List<AudioFile>>{};
    if (!_searching) {
      for (final name in _allCollectionNames) {
        map[name] = [];
      }
    }
    for (final f in _visibleFiles) {
      map.putIfAbsent(f.collection, () => []).add(f);
    }
    final sortedKeys = map.keys.toList();
    switch (_collectionSortBy) {
      case 'files':
        sortedKeys.sort((a, b) => map[b]!.length.compareTo(map[a]!.length));
        break;
      case 'recent':
        DateTime mostRecent(String k) {
          final files = map[k]!;
          if (files.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
          return files.map((f) => f.dateAdded).reduce((a, b) => a.isAfter(b) ? a : b);
        }

        sortedKeys.sort((a, b) => mostRecent(b).compareTo(mostRecent(a)));
        break;
      case 'name':
      default:
        sortedKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return {for (final k in sortedKeys) k: map[k]!};
  }

  /// A bigger, labeled app-bar action - icon on top, a short caption
  /// underneath - instead of a bare icon that only reveals what it does on
  /// a long-press tooltip. Reads the AppBar's own IconTheme so it matches
  /// whatever color a plain IconButton would already show here.
  Widget _labeledAppBarAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final baseColor = IconTheme.of(context).color ?? Colors.white;
    final color = onPressed != null ? baseColor : baseColor.withOpacity(0.38);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Selects every currently-visible file (respects search) if not all of
  /// them are already selected, otherwise clears the selection - one button
  /// does both jobs like most "select all" toggles.
  void _selectAllOrNone() {
    final visibleIds = _visibleFiles.map((f) => f.id).toSet();
    setState(() {
      if (_selectedIds.containsAll(visibleIds) && _selectedIds.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(visibleIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final selected = _files.where((f) => _selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) return;

    final ownsAny = <AudioFile, bool>{};
    for (final f in selected) {
      ownsAny[f] = await _appOwnsFile(f);
    }
    final anyOwned = ownsAny.values.any((v) => v);
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selected.length} file${selected.length == 1 ? '' : 's'}?'),
        content: Text(
          'All of their sessions and notes will be removed too. '
          '${anyOwned ? 'Any recordings the app itself made will be deleted from the device - this can\'t be undone. ' : ''}'
          'Imported MP3s stay on your device - only removed from this library.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final file in selected) {
      await _storage.deleteAudioFile(file.id);
      await _transcripts.delete(file.id);
      if (ownsAny[file] == true) {
        try {
          final f = File(file.path);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Best effort - not worth blocking the rest of the batch on this.
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${selected.length} file${selected.length == 1 ? '' : 's'}')),
      );
      setState(() {
        _selectMode = false;
        _selectedIds.clear();
      });
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = _files.isNotEmpty;
    final visibleIds = _visibleFiles.map((f) => f.id).toSet();
    final allSelected = visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds);
    return PopScope(
      canPop: _currentPath.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUpOrPop();
      },
      child: Scaffold(
      appBar: _selectMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: _toggleSelectMode,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                _labeledAppBarAction(
                  context,
                  icon: Icons.select_all,
                  label: allSelected ? 'Select None' : 'Select All',
                  onPressed: _selectAllOrNone,
                ),
                _labeledAppBarAction(
                  context,
                  icon: Icons.ios_share,
                  label: 'Share',
                  onPressed: _selectedIds.isEmpty ? null : _shareSelected,
                ),
                _labeledAppBarAction(
                  context,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
                const SizedBox(width: 4),
              ],
            )
          : AppBar(
              leading: _currentPath.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goUpOrPop,
                    ),
              title: Text(_currentPath.isEmpty ? 'My MP3s' : FolderTree.leafName(_currentPath)),
              actions: [
                if (hasFiles)
                  _labeledAppBarAction(
                    context,
                    icon: Icons.checklist,
                    label: 'Select',
                    onPressed: _toggleSelectMode,
                  ),
                _labeledAppBarAction(
                  context,
                  icon: Icons.account_tree,
                  label: 'By book',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LibraryTreeScreen()),
                    );
                  },
                ),
                _labeledAppBarAction(
                  context,
                  icon: Icons.create_new_folder,
                  label: 'New Folder',
                  onPressed: _createCollection,
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_files.isEmpty && _allCollectionNames.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.library_music,
                            size: 96,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'No audio files yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Import MP3s (you\'ll pick a collection/folder as you go, so different '
                          'Bible versions stay separate), or record yourself reading a passage.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openImport,
                            icon: const Icon(Icons.folder_open, size: 30),
                            label: const Text('Choose MP3 Files'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openRecordReading,
                            icon: const Icon(Icons.mic, size: 26),
                            label: const Text('Record a Reading'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search your files',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Clear search',
                                  onPressed: () => _searchController.clear(),
                                ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text('Files:', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
                                    items: const [
                                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                                      DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                                      DropdownMenuItem(value: 'title', child: Text('Title A-Z')),
                                      DropdownMenuItem(value: 'duration', child: Text('Longest')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Text('Folders:', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: _collectionSortBy,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    onChanged: (v) => setState(() => _collectionSortBy = v ?? _collectionSortBy),
                                    items: const [
                                      DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                                      DropdownMenuItem(value: 'files', child: Text('Most files')),
                                      DropdownMenuItem(value: 'recent', child: Text('Recently added')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: (_searching && _grouped().values.every((l) => l.isEmpty))
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No files match "${_searchController.text.trim()}"',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_currentPath.isNotEmpty && !_searching)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            FolderTree.displayPath(_currentPath),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      if (!_searching)
                        ..._childFoldersHere().map((name) {
                          final path = FolderTree.join(_currentPath, name);
                          final fileCount = _files.where((f) => FolderTree.isUnder(f.collection, path)).length;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary, size: 32),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(fileCount == 0 ? 'Empty' : '$fileCount file${fileCount == 1 ? '' : 's'}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (choice) {
                                  if (choice == 'rename') _renameFolder(name);
                                  if (choice == 'books') _addBibleBooksToFolder(name);
                                  if (choice == 'delete') _deleteChildFolder(name);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'rename', child: Text('Rename folder')),
                                  PopupMenuItem(value: 'books', child: Text('Add Bible book folders')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete folder')),
                                ],
                              ),
                              onTap: () => setState(() => _currentPath = path),
                            ),
                          );
                        }),
                      ...(_searching ? _visibleFiles : _filesHere()).map((file) {
                            final selected = _selectedIds.contains(file.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: _selectMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) => _toggleSelected(file.id),
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.audio_file,
                                        size: 26,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                              title: Text(file.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              // Real captions can take a long time to generate (Whisper on a long
                              // file) - showing whether they're already done right here means you
                              // don't have to open each file to check, or lose track of which ones
                              // you've already run.
                              subtitle: Row(
                                children: [
                                  Text(_formatDuration(file.duration)),
                                  if (file.transcriptReady) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.closed_caption, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Captions ready',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: _selectMode
                                  ? null
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    tooltip: 'Rename, move, share, or delete',
                                    onSelected: (choice) {
                                      if (choice == 'edit') {
                                        _editFile(file);
                                      } else if (choice == 'share') {
                                        _shareAudioFile(file);
                                      } else if (choice == 'delete') {
                                        _deleteFile(file);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('Rename / move'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'share',
                                        child: ListTile(
                                          leading: Icon(Icons.ios_share),
                                          title: Text('Share / save audio file'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Delete'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.chevron_right, size: 28),
                                ],
                              ),
                              onTap: () {
                                if (_selectMode) {
                                  _toggleSelected(file.id);
                                  return;
                                }
                                Navigator.of(context)
                                    .push(
                                  MaterialPageRoute(
                                    builder: (_) => SessionsScreen(
                                      audioFileId: file.id,
                                      title: file.title,
                                    ),
                                  ),
                                )
                                    .then((_) => _load());
                              },
                            ),
                            );
                          }),
                    ],
                  ),
                ),
                    ),
                  ],
                ),
      floatingActionButton: _selectMode
          ? null
          : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'recordReading',
            onPressed: _openRecordReading,
            icon: const Icon(Icons.mic),
            label: const Text('Record'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'importMp3s',
            onPressed: _openImport,
            icon: const Icon(Icons.folder_open, size: 30),
            label: const Text('Import MP3s'),
          ),
        ],
      ),
    ),
    );
  }
}
