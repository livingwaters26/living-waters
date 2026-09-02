import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'bible_text_service.dart';
import 'folder_tree.dart';
import 'safe_json.dart';

/// Simple beginner-friendly storage.
/// Saves everything as JSON files in the app's documents folder.
/// No complicated code generation required.
class SimpleStorage {
  static const _audioFilesName = 'audio_files.json';
  static const _sessionsName = 'sessions.json';
  static const _notesName = 'notes.json';
  static const _collectionsName = 'collections.json';
  static const _sessionFoldersName = 'session_folders.json';

  // Always offered as an option even before anything's been saved into it,
  // since it's a named destination the recorder screen suggests by default.
  static const List<String> _seedCollections = ['Personal Readings'];

  Future<Directory> _docsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _docsDir();
    return File(p.join(dir.path, name));
  }

  // ---------- Audio files ----------

  // Uses SafeJson instead of a raw jsonDecode: a corrupted/partially-written
  // audio_files.json used to throw here uncaught, which crashed anything
  // downstream that called this (including the import screen - the whole
  // app would exit). Now a bad file is salvaged if possible, backed up to
  // audio_files.json.bad, and treated as an empty library instead of taking
  // the app down.
  Future<List<AudioFile>> loadAudioFiles() async {
    final file = await _file(_audioFilesName);
    final list = await SafeJson.readList(file);
    return list.map((e) => AudioFile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAudioFiles(List<AudioFile> files) async {
    final file = await _file(_audioFilesName);
    final text = jsonEncode(files.map((f) => f.toMap()).toList());
    await file.writeAsString(text);
  }

  Future<void> addAudioFile(AudioFile audio) async {
    final list = await loadAudioFiles();
    list.add(audio);
    await saveAudioFiles(list);
  }

  /// Updates one already-imported/recorded file's fields (e.g. renaming it
  /// or moving it to a different collection) in place.
  Future<void> updateAudioFile(AudioFile updated) async {
    final list = await loadAudioFiles();
    final index = list.indexWhere((f) => f.id == updated.id);
    if (index >= 0) {
      list[index] = updated;
      await saveAudioFiles(list);
    }
  }

  /// Removes an audio file from the library along with every Session and
  /// Note that belonged to it, so nothing orphaned is left behind. Does NOT
  /// touch the actual audio file on disk - that's the caller's job (and it
  /// should only happen for files the app itself created, like recordings,
  /// never an imported MP3 living elsewhere on the device).
  Future<void> deleteAudioFile(String audioFileId) async {
    final files = await loadAudioFiles();
    files.removeWhere((f) => f.id == audioFileId);
    await saveAudioFiles(files);

    final sessions = await loadSessions();
    final removedSessionIds =
        sessions.where((s) => s.audioFileId == audioFileId).map((s) => s.id).toSet();
    final remainingSessions = sessions.where((s) => s.audioFileId != audioFileId).toList();
    await saveSessions(remainingSessions);

    if (removedSessionIds.isNotEmpty) {
      final notes = await loadNotes();
      final remainingNotes = notes.where((n) => !removedSessionIds.contains(n.sessionId)).toList();
      await saveNotes(remainingNotes);
    }
  }

  // ---------- Collections (the "folders" MP3s get grouped into) ----------

  /// Every collection name worth showing as a choice - explicitly-created
  /// ones (even if nothing's been saved into them yet) plus whatever's
  /// actually in use on existing audio files, deduped and sorted.
  Future<List<String>> loadCollectionNames() async {
    final names = <String>{..._seedCollections};

    final file = await _file(_collectionsName);
    final storedNames = await SafeJson.readList(file);
    names.addAll(storedNames.cast<String>());

    final audioFiles = await loadAudioFiles();
    names.addAll(audioFiles.map((f) => f.collection));

    final sorted = names.where((n) => n.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Explicitly creates a collection name so it shows up as a choice even
  /// before any file has been saved into it (lets the user "add a folder"
  /// ahead of time).
  Future<void> addCollectionName(String name) async {
    await addCollectionNames([name]);
  }

  Future<void> addCollectionNames(Iterable<String> names) async {
    final incoming = names
        .map((n) => FolderTree.normalize(n))
        .where((n) => n.isNotEmpty)
        .toList();
    if (incoming.isEmpty) return;

    final file = await _file(_collectionsName);
    final list = (await SafeJson.readList(file)).cast<String>();
    final seen = list.map(FolderTree.normalize).toSet();
    var changed = false;
    for (final name in incoming) {
      if (seen.add(name)) {
        list.add(name);
        changed = true;
      }
    }
    if (changed) {
      await file.writeAsString(jsonEncode(list));
    }
  }

  static const defaultTranslationFolders = [
    'Berean Standard Bible',
    'King James Version',
    'World English Bible',
    'American Standard Version (1901)',
    'Bible in Basic English',
    'Douay-Rheims 1899',
    'Great Adventure Bible',
    'NIV',
    'ESV',
  ];

  /// Creates each default translation folder and a subfolder for every
  /// Bible book under it. Catholic / Great Adventure folders get Apocrypha
  /// books in Catholic order. Safe to call more than once.
  Future<int> ensureTranslationBookFolders({
    List<String>? translations,
    List<String>? books,
  }) async {
    final versions = translations ?? defaultTranslationFolders;
    final paths = <String>[];
    for (final version in versions) {
      paths.add(version);
      final bookNames = (books != null && books.isNotEmpty)
          ? books
          : BibleTextService.booksForTranslationFolder(version);
      for (final book in bookNames) {
        paths.add(FolderTree.join(version, book));
      }
    }
    final before = (await SafeJson.readList(await _file(_collectionsName))).length;
    await addCollectionNames(paths);
    final after = (await SafeJson.readList(await _file(_collectionsName))).length;
    return after - before;
  }

  Future<int> addBibleBookFolders(String translationFolder, List<String> books) async {
    final root = FolderTree.normalize(translationFolder);
    if (root.isEmpty || books.isEmpty) return 0;
    final paths = <String>[root, ...books.map((book) => FolderTree.join(root, book))];
    final before = (await SafeJson.readList(await _file(_collectionsName))).length;
    await addCollectionNames(paths);
    final after = (await SafeJson.readList(await _file(_collectionsName))).length;
    return after - before;
  }

  /// Removes an explicitly-created collection name so it stops showing up
  /// as a folder. Only removes it from the saved list of names - a
  /// collection with no name entry here can still reappear on its own if
  /// any AudioFile still uses it (see loadCollectionNames), and the
  /// built-in 'Personal Readings' folder is a permanent seed name that
  /// isn't stored here at all, so this can't remove it either way.
  Future<void> removeCollectionName(String name) async {
    final file = await _file(_collectionsName);
    if (!await file.exists()) return;
    final list = (await SafeJson.readList(file)).cast<String>();
    list.remove(name);
    await file.writeAsString(jsonEncode(list));
  }

  /// Renames a library folder and every nested path under it.
  Future<void> renameLibraryFolder(String oldPath, String newPath) async {
    final from = FolderTree.normalize(oldPath);
    final to = FolderTree.normalize(newPath);
    if (from.isEmpty || from == to) return;

    final files = await loadAudioFiles();
    var changed = false;
    for (var i = 0; i < files.length; i++) {
      final next = FolderTree.renamePrefix(files[i].collection, from, to);
      if (next != files[i].collection) {
        files[i] = files[i].copyWith(collection: next);
        changed = true;
      }
    }
    if (changed) await saveAudioFiles(files);

    final file = await _file(_collectionsName);
    final list = (await SafeJson.readList(file)).cast<String>();
    final rewritten = <String>{};
    for (final name in list) {
      rewritten.add(FolderTree.renamePrefix(name, from, to));
    }
    rewritten.removeWhere((n) => n.trim().isEmpty);
    await file.writeAsString(jsonEncode(rewritten.toList()));
  }

  Future<List<String>> loadSessionFolderPaths(String audioFileId) async {
    final file = await _file(_sessionFoldersName);
    final list = await SafeJson.readList(file);
    final paths = <String>{};
    for (final raw in list) {
      if (raw is Map) {
        if (raw['audioFileId'] == audioFileId) {
          final path = FolderTree.normalize('${raw['path'] ?? ''}');
          if (path.isNotEmpty) paths.add(path);
        }
      }
    }
    final sessions = await loadSessions(audioFileId: audioFileId);
    for (final session in sessions) {
      final path = FolderTree.normalize(session.folderPath);
      if (path.isNotEmpty) paths.add(path);
    }
    final sorted = paths.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Future<void> addSessionFolderPath(String audioFileId, String path) async {
    final normalized = FolderTree.normalize(path);
    if (normalized.isEmpty) return;
    final file = await _file(_sessionFoldersName);
    final list = await SafeJson.readList(file);
    final already = list.any((raw) =>
        raw is Map && raw['audioFileId'] == audioFileId && FolderTree.normalize('${raw['path'] ?? ''}') == normalized);
    if (already) return;
    list.add({'audioFileId': audioFileId, 'path': normalized});
    await file.writeAsString(jsonEncode(list));
  }

  Future<void> removeSessionFolderPath(String audioFileId, String path) async {
    final normalized = FolderTree.normalize(path);
    final file = await _file(_sessionFoldersName);
    if (!await file.exists()) return;
    final list = await SafeJson.readList(file);
    list.removeWhere((raw) =>
        raw is Map && raw['audioFileId'] == audioFileId && FolderTree.normalize('${raw['path'] ?? ''}') == normalized);
    await file.writeAsString(jsonEncode(list));
  }

  Future<void> renameSessionFolder(String audioFileId, String oldPath, String newPath) async {
    final from = FolderTree.normalize(oldPath);
    final to = FolderTree.normalize(newPath);
    if (from.isEmpty || from == to) return;

    final sessions = await loadSessions();
    var changed = false;
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].audioFileId != audioFileId) continue;
      final next = FolderTree.renamePrefix(sessions[i].folderPath, from, to);
      if (next != sessions[i].folderPath) {
        sessions[i] = sessions[i].copyWith(folderPath: next);
        changed = true;
      }
    }
    if (changed) await saveSessions(sessions);

    final file = await _file(_sessionFoldersName);
    final list = await SafeJson.readList(file);
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is Map && raw['audioFileId'] == audioFileId) {
        raw['path'] = FolderTree.renamePrefix('${raw['path'] ?? ''}', from, to);
      }
    }
    list.removeWhere((raw) => raw is Map && raw['audioFileId'] == audioFileId && FolderTree.normalize('${raw['path'] ?? ''}').isEmpty);
    await file.writeAsString(jsonEncode(list));
  }

  // ---------- Sessions ----------

  Future<List<Session>> loadSessions({String? audioFileId}) async {
    final file = await _file(_sessionsName);
    final list = await SafeJson.readList(file);
    var sessions = list.map((e) => Session.fromMap(e as Map<String, dynamic>)).toList();
    if (audioFileId != null) {
      sessions = sessions.where((s) => s.audioFileId == audioFileId).toList();
    }
    // Newest first
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<void> saveSessions(List<Session> sessions) async {
    final file = await _file(_sessionsName);
    final text = jsonEncode(sessions.map((s) => s.toMap()).toList());
    await file.writeAsString(text);
  }

  Future<void> addSession(Session session) async {
    final list = await loadSessions();
    list.add(session);
    await saveSessions(list);
  }

  Future<void> updateSession(Session session) async {
    final list = await loadSessions();
    final index = list.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      list[index] = session;
      await saveSessions(list);
    }
  }

  // ---------- Notes ----------

  Future<List<Note>> loadNotes({String? sessionId}) async {
    final file = await _file(_notesName);
    final list = await SafeJson.readList(file);
    var notes = list.map((e) => Note.fromMap(e as Map<String, dynamic>)).toList();
    if (sessionId != null) {
      notes = notes.where((n) => n.sessionId == sessionId).toList();
    }
    // Newest first
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  Future<void> saveNotes(List<Note> notes) async {
    final file = await _file(_notesName);
    final text = jsonEncode(notes.map((n) => n.toMap()).toList());
    await file.writeAsString(text);
  }

  Future<void> addNote(Note note) async {
    final list = await loadNotes();
    list.add(note);
    await saveNotes(list);
  }

  /// Called on app start to finish any notes that were interrupted.
  Future<List<Note>> findIncompleteNotes() async {
    final all = await loadNotes();
    return all.where((n) => !n.isComplete).toList();
  }
}
