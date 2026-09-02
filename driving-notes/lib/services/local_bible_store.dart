import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'bible_chunk_parser.dart';
import 'bible_text_service.dart';

class LocalTranslationInfo {
  final String id;
  final String name;
  final int verseCount;
  final int bookCount;
  final List<String> books;

  const LocalTranslationInfo({
    required this.id,
    required this.name,
    required this.verseCount,
    required this.bookCount,
    required this.books,
  });
}

class MergeReport {
  final int added;
  final int replaced;
  final int unchanged;
  final int inFileDupes;
  final int booksTouched;
  final int overlapMatched;
  final int overlapMismatch;

  const MergeReport({
    required this.added,
    required this.replaced,
    required this.unchanged,
    required this.inFileDupes,
    required this.booksTouched,
    this.overlapMatched = 0,
    this.overlapMismatch = 0,
  });
}

class ChunkPreview {
  final List<String> bookLines;
  final int verseCount;
  final int overlapMatched;
  final int overlapMismatch;
  final List<String> mismatchRefs;

  const ChunkPreview({
    required this.bookLines,
    required this.verseCount,
    required this.overlapMatched,
    required this.overlapMismatch,
    required this.mismatchRefs,
  });
}

/// On-device store for imported translations.
/// Duplicate = same translation + same book id + same chapter + same verse.
/// 1 Kings and 1 Chronicles never collide.
class LocalBibleStore {
  static const prefix = 'local_';

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'local_bibles'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String idForName(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '$prefix${slug.isEmpty ? 'custom' : slug}';
  }

  static bool isLocalId(String translation) => translation.startsWith(prefix);

  Future<File> _manifestFile(String id) async {
    return File(p.join((await _root()).path, id, 'manifest.json'));
  }

  Future<File> _chapterFile(String id, String bookId, int chapter) async {
    final dir = Directory(p.join((await _root()).path, id, bookId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '$chapter.json'));
  }

  Future<List<LocalTranslationInfo>> listTranslations() async {
    final root = await _root();
    final out = <LocalTranslationInfo>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final mf = File(p.join(entity.path, 'manifest.json'));
      if (!await mf.exists()) continue;
      try {
        final map = jsonDecode(await mf.readAsString()) as Map<String, dynamic>;
        final books = (map['books'] as List?)?.map((e) => '$e').toList() ?? [];
        out.add(LocalTranslationInfo(
          id: id,
          name: map['name'] as String? ?? id,
          verseCount: map['verseCount'] as int? ?? 0,
          bookCount: books.length,
          books: books,
        ));
      } catch (_) {}
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<Map<String, String>> nameMap() async {
    final map = <String, String>{};
    for (final t in await listTranslations()) {
      map[t.id] = '${t.name} (on device)';
    }
    return map;
  }

  Future<int> chapterCount(String id, String bookId) async {
    final dir = Directory(p.join((await _root()).path, id, bookId));
    if (!await dir.exists()) return 0;
    var max = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final n = int.tryParse(p.basenameWithoutExtension(entity.path));
      if (n != null && n > max) max = n;
    }
    return max;
  }

  Future<List<BibleVerse>> chapterVerses(String id, String bookId, int chapter) async {
    final file = await _chapterFile(id, bookId, chapter);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      final bookName = BibleTextService().bookNameForId(bookId) ?? bookId;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return BibleVerse(
          book: bookName,
          chapter: chapter,
          verse: m['v'] as int,
          text: m['t'] as String,
        );
      }).toList()
        ..sort((a, b) => a.verse.compareTo(b.verse));
    } catch (_) {
      return [];
    }
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<ChunkPreview> previewChunk({
    required String translationName,
    required List<ParsedVerse> verses,
  }) async {
    final id = idForName(translationName);
    final byBook = <String, List<ParsedVerse>>{};
    for (final v in verses) {
      byBook.putIfAbsent(v.bookName, () => []).add(v);
    }
    final bookLines = <String>[];
    final order = BibleTextService.bookOrder;
    final names = byBook.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
      });
    for (final name in names) {
      final list = byBook[name]!;
      final chapters = list.map((e) => e.chapter).toSet().toList()..sort();
      final lo = chapters.first;
      final hi = chapters.last;
      bookLines.add('$name ch $lo–$hi (${list.length} verses)');
    }

    var matched = 0;
    var mismatch = 0;
    final mismatchRefs = <String>[];
    final grouped = <String, List<ParsedVerse>>{};
    for (final v in verses) {
      grouped.putIfAbsent('${v.bookId}|${v.chapter}', () => []).add(v);
    }
    for (final entry in grouped.entries) {
      final parts = entry.key.split('|');
      final stored = await chapterVerses(id, parts[0], int.parse(parts[1]));
      final byVerse = {for (final s in stored) s.verse: s.text};
      for (final v in entry.value) {
        final old = byVerse[v.verse];
        if (old == null) continue;
        if (_norm(old) == _norm(v.text)) {
          matched++;
        } else {
          mismatch++;
          if (mismatchRefs.length < 8) {
            mismatchRefs.add('${v.bookName} ${v.chapter}:${v.verse}');
          }
        }
      }
    }
    return ChunkPreview(
      bookLines: bookLines,
      verseCount: verses.length,
      overlapMatched: matched,
      overlapMismatch: mismatch,
      mismatchRefs: mismatchRefs,
    );
  }

  Future<MergeReport> mergeChunk({
    required String translationName,
    required List<ParsedVerse> verses,
    required int inFileDupes,
    bool replaceMismatches = false,
  }) async {
    final id = idForName(translationName);
    var added = 0;
    var replaced = 0;
    var unchanged = 0;
    var overlapMatched = 0;
    var overlapMismatch = 0;
    final books = <String>{};

    final grouped = <String, List<ParsedVerse>>{};
    for (final v in verses) {
      grouped.putIfAbsent('${v.bookId}|${v.chapter}', () => []).add(v);
      books.add(v.bookName);
    }

    for (final entry in grouped.entries) {
      final parts = entry.key.split('|');
      final bookId = parts[0];
      final chapter = int.parse(parts[1]);
      final file = await _chapterFile(id, bookId, chapter);
      final existing = <int, String>{};
      if (await file.exists()) {
        try {
          final list = jsonDecode(await file.readAsString()) as List<dynamic>;
          for (final e in list) {
            final m = e as Map<String, dynamic>;
            existing[m['v'] as int] = m['t'] as String;
          }
        } catch (_) {}
      }
      for (final v in entry.value) {
        if (!existing.containsKey(v.verse)) {
          existing[v.verse] = v.text;
          added++;
        } else if (_norm(existing[v.verse]!) == _norm(v.text)) {
          unchanged++;
          overlapMatched++;
        } else {
          overlapMismatch++;
          if (replaceMismatches) {
            existing[v.verse] = v.text;
            replaced++;
          } else {
            unchanged++;
          }
        }
      }
      final out = existing.entries.map((e) => {'v': e.key, 't': e.value}).toList()
        ..sort((a, b) => (a['v'] as int).compareTo(b['v'] as int));
      await file.writeAsString(jsonEncode(out));
    }

    await _writeManifest(id, translationName);
    return MergeReport(
      added: added,
      replaced: replaced,
      unchanged: unchanged,
      inFileDupes: inFileDupes,
      booksTouched: books.length,
      overlapMatched: overlapMatched,
      overlapMismatch: overlapMismatch,
    );
  }

  Future<void> _writeManifest(String id, String name) async {
    final root = Directory(p.join((await _root()).path, id));
    final books = <String>[];
    var verses = 0;
    await for (final bookDir in root.list()) {
      if (bookDir is! Directory) continue;
      final bookId = p.basename(bookDir.path);
      if (bookId == '.') continue;
      final bookName = BibleTextService().bookNameForId(bookId);
      if (bookName != null) books.add(bookName);
      await for (final ch in bookDir.list()) {
        if (ch is! File || !ch.path.endsWith('.json')) continue;
        try {
          final list = jsonDecode(await ch.readAsString()) as List<dynamic>;
          verses += list.length;
        } catch (_) {}
      }
    }
    books.sort((a, b) {
      final oa = BibleTextService.bookOrder.indexOf(a);
      final ob = BibleTextService.bookOrder.indexOf(b);
      return oa.compareTo(ob);
    });
    final mf = await _manifestFile(id);
    await mf.writeAsString(jsonEncode({
      'id': id,
      'name': name,
      'verseCount': verses,
      'books': books,
    }));
  }

  Future<void> deleteTranslation(String id) async {
    final dir = Directory(p.join((await _root()).path, id));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
