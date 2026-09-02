import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/folder_tree.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import 'player_screen.dart';

/// Sessions for one audio file, with computer-style nested folders.
class SessionsScreen extends ConsumerStatefulWidget {
  final String audioFileId;
  final String title;

  const SessionsScreen({
    super.key,
    required this.audioFileId,
    required this.title,
  });

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _storage = SimpleStorage();
  final _transcripts = TranscriptService();
  List<Session> _sessions = [];
  List<String> _folderPaths = [];
  List<TranscriptSegment> _segments = [];
  bool _loading = true;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _storage.loadSessions(audioFileId: widget.audioFileId);
    final folders = await _storage.loadSessionFolderPaths(widget.audioFileId);
    final segs = await _transcripts.load(widget.audioFileId);
    if (mounted) {
      setState(() {
        _sessions = list;
        _folderPaths = folders;
        _segments = segs ?? [];
        _loading = false;
      });
    }
  }

  String _defaultLabel() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '${widget.title} – ${now.month}/${now.day}/${now.year} $h:$m $ampm';
  }

  Future<void> _createNewSession() async {
    final session = Session(
      audioFileId: widget.audioFileId,
      label: _defaultLabel(),
      folderPath: _currentPath,
    );
    await _storage.addSession(session);
    await _load();

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            audioFileId: widget.audioFileId,
            sessionId: session.id,
            sessionLabel: session.label,
            audioTitle: widget.title,
          ),
        ),
      );
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
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
    if (name == null || name.isEmpty || name.contains('/')) return;
    await _storage.addSessionFolderPath(widget.audioFileId, FolderTree.join(_currentPath, name));
    await _load();
  }

  Future<void> _renameFolder(String childName) async {
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
    if (name == null || name.isEmpty || name == childName || name.contains('/')) return;
    await _storage.renameSessionFolder(
      widget.audioFileId,
      FolderTree.join(_currentPath, childName),
      FolderTree.join(_currentPath, name),
    );
    await _load();
  }

  Future<void> _deleteFolder(String childName) async {
    final path = FolderTree.join(_currentPath, childName);
    final hasSessions = _sessions.any((s) => FolderTree.isUnder(s.folderPath, path));
    final hasKids = FolderTree.childFolders(_folderPaths, path).isNotEmpty;
    if (hasSessions || hasKids) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Move or delete what is inside this folder first.')),
        );
      }
      return;
    }
    await _storage.removeSessionFolderPath(widget.audioFileId, path);
    await _load();
  }

  Future<void> _renameOrMoveSession(Session session) async {
    final labelController = TextEditingController(text: session.label);
    final folderController = TextEditingController(text: session.folderPath);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename / move session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: folderController,
              decoration: const InputDecoration(
                labelText: 'Folder path',
                hintText: 'Leave blank for the top of this file',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final label = labelController.text.trim();
    await _storage.updateSession(session.copyWith(
      label: label.isEmpty ? session.label : label,
      folderPath: FolderTree.normalize(folderController.text),
    ));
    await _load();
  }

  String _formatPosition(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _goUpOrPop() {
    if (_currentPath.isNotEmpty) {
      setState(() => _currentPath = FolderTree.parentOf(_currentPath));
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final foldersHere = FolderTree.childFolders(_folderPaths, _currentPath);
    final sessionsHere = _sessions.where((s) => FolderTree.normalize(s.folderPath) == FolderTree.normalize(_currentPath)).toList();

    return PopScope(
      canPop: _currentPath.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUpOrPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_goUpOrPop()) Navigator.of(context).maybePop();
            },
          ),
          title: Text(_currentPath.isEmpty ? widget.title : FolderTree.leafName(_currentPath)),
          actions: [
            IconButton(
              tooltip: 'New folder',
              icon: const Icon(Icons.create_new_folder),
              onPressed: _createFolder,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_currentPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.title} › ${FolderTree.displayPath(_currentPath)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createNewSession,
                  icon: const Icon(Icons.add, size: 30),
                  label: const Text('New Session'),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (foldersHere.isEmpty && sessionsHere.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Nothing in this folder yet.\nMake a subfolder or a new session.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            ...foldersHere.map((name) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary, size: 32),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (choice) {
                                      if (choice == 'rename') _renameFolder(name);
                                      if (choice == 'delete') _deleteFolder(name);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'rename', child: Text('Rename folder')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete folder')),
                                    ],
                                  ),
                                  onTap: () => setState(() => _currentPath = FolderTree.join(_currentPath, name)),
                                ),
                              );
                            }),
                            ...sessionsHere.map((s) {
                              final caption = _transcripts.segmentAt(_segments, s.lastPosition)?.text;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    child: Icon(
                                      Icons.menu_book,
                                      size: 26,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (caption != null && caption.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '"${caption.trim()}"',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Last at ${_formatPosition(s.lastPosition)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Rename / move',
                                        icon: const Icon(Icons.drive_file_move_outline),
                                        onPressed: () => _renameOrMoveSession(s),
                                      ),
                                      Icon(
                                        Icons.play_circle_fill,
                                        size: 44,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlayerScreen(
                                          audioFileId: widget.audioFileId,
                                          sessionId: s.id,
                                          sessionLabel: s.label,
                                          audioTitle: widget.title,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
