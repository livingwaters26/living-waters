import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_bible_store.dart';

/// One verse of scripture text.
class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$chapter:$verse';
}

/// Looks up real Bible text - free, no account, no key, public-domain
/// translations only. Used instead of speech-to-text: the actual words are
/// already known for scripture, so there's no need to guess them from
/// audio. This also powers the pure text-to-speech reading mode.
///
/// Two backends, picked per-translation:
///  - bible-api.com for web/asv/bbe/dra
///  - bible.helloao.org (the "Free Use Bible API") for bsb - the Berean
///    Standard Bible isn't on bible-api.com, but it's CC0/public domain and
///    available there instead.
///
/// Every chapter fetched over the network is cached to disk. Once a chapter
/// has been read once (while online), it's available again with no
/// internet connection at all - this is what makes "load a book before you
/// leave, then read it with no signal" actually work.
class BibleTextService {
  static const _bibleApiBaseUrl = 'https://bible-api.com/data';
  static const _helloAoBaseUrl = 'https://bible.helloao.org/api';

  /// Public-domain translations worth offering. BSB (Berean Standard Bible)
  /// listed first - it's the most modern, easy-to-read option here, and
  /// it's CC0/public domain (bereanbible.com). KJV added back by request -
  /// this is the standard 66-book Protestant canon (bible-api.com's 'kjv',
  /// public domain). NOTE on Apocrypha (checked live, not assumed): neither
  /// bible-api.com nor bible.helloao.org actually serves a working
  /// Apocrypha-inclusive edition - helloao lists an "eng-kjv" entry
  /// literally named "King James Version + Apocrypha", but its actual
  /// books.json only returns the same 66 standard books (a mislabeled
  /// catalog entry, confirmed by fetching it directly) - and there's no
  /// Apocrypha edition of the BSB anywhere; it's a modern Protestant-canon
  /// translation. So Apocrypha isn't offered here - it would need a
  /// different data source than what's free/available today.
  static const Map<String, String> translations = {
    'bsb': 'Berean Standard Bible',
    'kjv': 'King James Version',
    'web': 'World English Bible',
    'asv': 'American Standard Version (1901)',
    'bbe': 'Bible in Basic English',
    'dra': 'Douay-Rheims 1899',
  };

  static bool _usesHelloAo(String translation) => translation == 'bsb';

  /// Built-in plus imported on-device translations.
  static Future<Map<String, String>> allTranslations() async {
    final local = await LocalBibleStore().nameMap();
    return {...translations, ...local};
  }

  static const List<String> bookOrder = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
    'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
    'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
    'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
    '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation',
    'Tobit', 'Judith', 'Wisdom', 'Sirach', 'Baruch',
    '1 Maccabees', '2 Maccabees',
  ];

  /// Deuterocanon / Apocrypha titles used as library subfolders.
  static const List<String> apocryphaBooks = [
    'Tobit',
    'Judith',
    '1 Maccabees',
    '2 Maccabees',
    'Wisdom',
    'Sirach',
    'Baruch',
  ];

  /// Catholic Bible order (Douay-Rheims / Great Adventure), 73 books.
  static const List<String> catholicBookOrder = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah',
    'Tobit', 'Judith', 'Esther', '1 Maccabees', '2 Maccabees',
    'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    'Wisdom', 'Sirach',
    'Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Ezekiel', 'Daniel',
    'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
    'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
    'Tobit', 'Judith', 'Wisdom', 'Sirach', 'Baruch',
    '1 Maccabees', '2 Maccabees',
  ];

  /// Sort key for any mix of Protestant, Catholic, and extra Apocrypha folders.
  static const List<String> folderSortOrder = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah',
    'Tobit', 'Judith', 'Esther', '1 Maccabees', '2 Maccabees',
    '1 Esdras', '2 Esdras',
    'Job', 'Psalms', 'Psalm 151', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    'Wisdom', 'Sirach',
    'Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Letter of Jeremiah',
    'Ezekiel', 'Daniel', 'Prayer of Azariah', 'Susanna', 'Bel and the Dragon',
    'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
    'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Prayer of Manasseh', '3 Maccabees', '4 Maccabees',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
    'Tobit', 'Judith', 'Wisdom', 'Sirach', 'Baruch',
    '1 Maccabees', '2 Maccabees',
  ];

  static bool translationIncludesApocrypha(String folderName) {
    final name = folderName.toLowerCase();
    return name.contains('douay') ||
        name.contains('rheims') ||
        name.contains('great adventure') ||
        name.contains('nab') ||
        name.contains('nabre') ||
        name.contains('catholic') ||
        name.contains('apocrypha') ||
        name.contains('deuterocanon');
  }

  static List<String> booksForTranslationFolder(String folderName, {bool includeApocrypha = false}) {
    if (includeApocrypha || translationIncludesApocrypha(folderName)) {
      return catholicBookOrder;
    }
    return bookOrder;
  }

  /// Standard 3-letter USFM-style book codes - both bible-api.com and
  /// bible.helloao.org use this same convention, so one map covers both.
  static const Map<String, String> _bookIds = {
    'genesis': 'GEN', 'exodus': 'EXO', 'leviticus': 'LEV', 'numbers': 'NUM',
    'deuteronomy': 'DEU', 'joshua': 'JOS', 'judges': 'JDG', 'ruth': 'RUT',
    '1 samuel': '1SA', '2 samuel': '2SA', '1 kings': '1KI', '2 kings': '2KI',
    '1 chronicles': '1CH', '2 chronicles': '2CH', 'ezra': 'EZR',
    'nehemiah': 'NEH', 'esther': 'EST', 'job': 'JOB', 'psalms': 'PSA',
    'psalm': 'PSA', 'proverbs': 'PRO', 'ecclesiastes': 'ECC',
    'song of solomon': 'SNG', 'song of songs': 'SNG', 'canticles': 'SNG',
    'isaiah': 'ISA', 'jeremiah': 'JER', 'lamentations': 'LAM',
    'ezekiel': 'EZK', 'daniel': 'DAN', 'hosea': 'HOS', 'joel': 'JOL',
    'amos': 'AMO', 'obadiah': 'OBA', 'jonah': 'JON', 'micah': 'MIC',
    'nahum': 'NAM', 'habakkuk': 'HAB', 'zephaniah': 'ZEP', 'haggai': 'HAG',
    'zechariah': 'ZEC', 'malachi': 'MAL', 'matthew': 'MAT', 'mark': 'MRK',
    'luke': 'LUK', 'john': 'JHN', 'acts': 'ACT', 'romans': 'ROM',
    '1 corinthians': '1CO', '2 corinthians': '2CO', 'galatians': 'GAL',
    'ephesians': 'EPH', 'philippians': 'PHP', 'colossians': 'COL',
    '1 thessalonians': '1TH', '2 thessalonians': '2TH', '1 timothy': '1TI',
    '2 timothy': '2TI', 'titus': 'TIT', 'philemon': 'PHM', 'hebrews': 'HEB',
    'james': 'JAS', '1 peter': '1PE', '2 peter': '2PE', '1 john': '1JN',
    '2 john': '2JN', '3 john': '3JN', 'jude': 'JUD', 'revelation': 'REV',
    'revelations': 'REV',
    'tobit': 'TOB', 'judith': 'JDT',
    'wisdom': 'WIS', 'wisdom of solomon': 'WIS',
    'sirach': 'SIR', 'ecclesiasticus': 'SIR',
    'baruch': 'BAR',
    '1 maccabees': '1MA', '2 maccabees': '2MA',
  };

  /// Tries to recognize a Bible book name from a loose title string like
  /// "02_Exodus", "John", or "1st_Corinthians" - or a title that names the
  /// book but ALSO has extra words tacked on, like "Numbers Chapter 10",
  /// "Numbers 10", or "Book of Numbers" (a bare-book-name exact match is
  /// tried first as a fast path; this whole-word search is the fallback so
  /// a title full of extra words still gets recognized). Returns the
  /// standard book id, or null if nothing matched.
  String? findBookId(String rawTitle) {
    var t = rawTitle.trim();
    t = t.replaceAll('_', ' ').replaceAll('-', ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    t = t.replaceFirst(RegExp(r'^(1st|first|i)\s'), '1 ');
    t = t.replaceFirst(RegExp(r'^(2nd|second|ii)\s'), '2 ');
    t = t.replaceFirst(RegExp(r'^(3rd|third|iii)\s'), '3 ');

    // Numbered books FIRST (1 Kings vs 1 Chronicles vs 3 John) before
    // stripping a leading folder number like "02 Exodus".
    final exactNumbered = _bookIds[t];
    if (exactNumbered != null) return exactNumbered;
    final candidatesFirst = _bookIds.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in candidatesFirst) {
      final pattern = RegExp(r'(^|\s)' + RegExp.escape(name) + r'(\s|$)');
      if (pattern.hasMatch(t)) return _bookIds[name];
    }

    t = t.replaceFirst(RegExp(r'^\d+[\s.]+'), '');
    final exact = _bookIds[t];
    if (exact != null) return exact;

    // Longest names first so a two/three-word book ("song of solomon", "1
    // corinthians") wins over any shorter overlap, and each match must sit
    // on a word boundary (surrounded by the start/end of the string or a
    // space) so short names like "job" or "acts" don't fire on part of an
    // unrelated word.
    final candidates = _bookIds.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in candidates) {
      final pattern = RegExp(r'(^|\s)' + RegExp.escape(name) + r'(\s|$)');
      if (pattern.hasMatch(t)) return _bookIds[name];
    }
    return null;
  }

  String bookIdFor(String bookName) => _bookIds[bookName.toLowerCase()]!;

  /// Reverse of bookIdFor - the human-readable book name (from bookOrder)
  /// for a given 3-letter id, or null if it's not a recognized id. Used to
  /// turn a guessed id (from findBookId) back into a name that
  /// ReadScriptureScreen's book picker understands.
  String? bookNameForId(String bookId) {
    for (final name in bookOrder) {
      if (_bookIds[name.toLowerCase()] == bookId) return name;
    }
    return null;
  }

  // ---------- Disk cache ----------

  /// Bumped round 31 after fixing the poetry-verse text extraction bug in
  /// _joinHelloAoContent (see its doc comment) - any chapter cached under
  /// the OLD parser may have empty/near-empty verse text for poetry books
  /// (Psalms, Proverbs, Job, Lamentations, Song of Solomon, poetic stretches
  /// elsewhere), and would keep replaying that broken data forever since
  /// the cache is checked before ever hitting the network again. Bumping
  /// this wipes every cached chapter/meta file once so they get re-fetched
  /// fresh with the corrected parsing - a one-time, cache-only reset, not a
  /// full app data wipe (nothing about the library, sessions, or notes is
  /// touched).
  static const int _cacheSchemaVersion = 2;
  static bool _cacheMigrationChecked = false;

  Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'bible_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (!_cacheMigrationChecked) {
      _cacheMigrationChecked = true;
      await _wipeCacheIfSchemaOutdated(dir);
    }
    return dir;
  }

  Future<void> _wipeCacheIfSchemaOutdated(Directory dir) async {
    final versionFile = File(p.join(dir.path, '_cache_schema_version.txt'));
    var storedVersion = 0;
    if (await versionFile.exists()) {
      try {
        storedVersion = int.parse((await versionFile.readAsString()).trim());
      } catch (_) {
        storedVersion = 0; // Corrupt marker - treat as outdated, wipe and rewrite it.
      }
    }
    if (storedVersion >= _cacheSchemaVersion) return;

    try {
      await for (final entry in dir.list()) {
        if (entry is File && entry.path != versionFile.path) {
          try {
            await entry.delete();
          } catch (_) {
            // Best-effort - a file that won't delete just gets overwritten
            // on the next fetch instead.
          }
        }
      }
      await versionFile.writeAsString('$_cacheSchemaVersion');
    } catch (_) {
      // Best-effort - worst case, stale cache entries linger and get
      // corrected chapter-by-chapter as each one happens to be re-fetched.
    }
  }

  Future<File> _metaCacheFile(String translation, String bookId) async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, '${translation}_${bookId}_meta.json'));
  }

  Future<File> _chapterCacheFile(String translation, String bookId, int chapter) async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, '${translation}_${bookId}_$chapter.json'));
  }

  /// Whether a chapter is already saved on disk - lets a caller skip the
  /// network-rate-limit pacing delay for chapters that won't actually hit
  /// the network.
  Future<bool> isChapterCached(String bookId, int chapter, String translation) async {
    return (await _chapterCacheFile(translation, bookId, chapter)).exists();
  }

  Future<dynamic> _getJson(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Bible text service returned HTTP ${response.statusCode} for $url');
      }
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  /// How many chapters a book has, per the given translation. Checks the
  /// on-disk cache first - no internet needed once this has been called
  /// successfully once for a given book/translation.
  Future<int> chapterCount(String bookId, String translation) async {
    if (LocalBibleStore.isLocalId(translation)) {
      return LocalBibleStore().chapterCount(translation, bookId);
    }
    final metaFile = await _metaCacheFile(translation, bookId);
    if (await metaFile.exists()) {
      try {
        final cached = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        return cached['numberOfChapters'] as int;
      } catch (_) {
        // Corrupt cache file - fall through and re-fetch from the network.
      }
    }

    final int total;
    if (_usesHelloAo(translation)) {
      final data = await _getJson('$_helloAoBaseUrl/BSB/$bookId/1.json');
      total = data['book']['numberOfChapters'] as int;
    } else {
      final index = await _getJson('$_bibleApiBaseUrl/$translation/$bookId');
      total = (index['chapters'] as List).length;
    }

    try {
      await metaFile.writeAsString(jsonEncode({'numberOfChapters': total}));
    } catch (_) {
      // Best-effort cache write - reading still works even if this fails.
    }
    return total;
  }

  /// Joins a helloao verse's "content" array (a mix of text fragments and
  /// non-text markers like footnote refs or line breaks) into one clean,
  /// readable string.
  ///
  /// Round 31: prose books (Matthew, etc.) represent each content entry as a
  /// bare string, but POETRY books (Psalms, Proverbs, Job, Lamentations,
  /// Song of Solomon, and poetic stretches elsewhere) instead wrap each line
  /// in an object like {"text": "...", "poem": 1} so a line break can be
  /// recorded - e.g. Psalm 3:2 is
  /// [{"text":"Many say of me,","poem":1}, {"text":"\"God will not deliver
  /// him.\"","poem":2}, "Selah", {"noteId":5}]. The old version only ever
  /// looked for bare strings, so it silently skipped every {"text": ...}
  /// object and kept just the bare "Selah" - meaning almost every verse in a
  /// poetry book came back completely empty text and got filtered out
  /// entirely by fetchChapter's isNotEmpty check, leaving only stray
  /// leftovers like "Selah" as if they were the ONLY verses in the chapter.
  /// That's exactly what made "Caption with Real Text" look frozen on
  /// Psalms - a single tiny leftover "verse" ended up spanning the entire
  /// file. Now a {"text": ...} object is unwrapped the same as a bare
  /// string; anything else (e.g. {"noteId": ...} footnote markers) is still
  /// skipped.
  String _joinHelloAoContent(List<dynamic> parts) {
    final buffer = StringBuffer();
    for (final part in parts) {
      String? text;
      if (part is String) {
        text = part;
      } else if (part is Map && part['text'] is String) {
        text = part['text'] as String;
      }
      if (text == null || text.isEmpty) continue; // skip noteId/lineBreak markers
      if (buffer.isNotEmpty) {
        final startsWithPunctuation = RegExp(r'^[,.;:!?)\]”"’]').hasMatch(text);
        if (!startsWithPunctuation) buffer.write(' ');
      }
      buffer.write(text);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Fetches every verse of a single chapter. Checks the on-disk cache
  /// first; only hits the network on a cache miss, and saves the result to
  /// disk afterward so the next read of this same chapter needs no
  /// internet at all - even after the app has been fully closed and
  /// reopened.
  Future<List<BibleVerse>> fetchChapter(
    String bookId,
    int chapter,
    String translation,
  ) async {
    if (LocalBibleStore.isLocalId(translation)) {
      return LocalBibleStore().chapterVerses(translation, bookId, chapter);
    }
    final cacheFile = await _chapterCacheFile(translation, bookId, chapter);
    if (await cacheFile.exists()) {
      try {
        final cached = (jsonDecode(await cacheFile.readAsString()) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        return cached
            .map((v) => BibleVerse(
                  book: v['book'] as String,
                  chapter: v['chapter'] as int,
                  verse: v['verse'] as int,
                  text: v['text'] as String,
                ))
            .toList();
      } catch (_) {
        // Corrupt cache file - fall through and re-fetch from the network.
      }
    }

    final verses = await _fetchChapterFromNetwork(bookId, chapter, translation);

    try {
      final encoded = jsonEncode(verses
          .map((v) => {'book': v.book, 'chapter': v.chapter, 'verse': v.verse, 'text': v.text})
          .toList());
      await cacheFile.writeAsString(encoded);
    } catch (_) {
      // Best-effort cache write - reading still works even if this fails.
    }

    return verses;
  }

  Future<List<BibleVerse>> _fetchChapterFromNetwork(
    String bookId,
    int chapter,
    String translation,
  ) async {
    if (_usesHelloAo(translation)) {
      final data = await _getJson('$_helloAoBaseUrl/BSB/$bookId/$chapter.json');
      final bookName = data['book']['name'] as String;
      final items = (data['chapter']['content'] as List).cast<Map<String, dynamic>>();
      return items
          .where((item) => item['type'] == 'verse')
          .map((item) => BibleVerse(
                book: bookName,
                chapter: chapter,
                verse: item['number'] as int,
                text: _joinHelloAoContent(item['content'] as List),
              ))
          .where((v) => v.text.isNotEmpty)
          .toList();
    }

    final data = await _getJson('$_bibleApiBaseUrl/$translation/$bookId/$chapter');
    final list = (data['verses'] as List).cast<Map<String, dynamic>>();
    return list
        .map((v) => BibleVerse(
              book: v['book'] as String,
              chapter: v['chapter'] as int,
              verse: v['verse'] as int,
              text: (v['text'] as String).trim(),
            ))
        .toList();
  }

  /// Fetches every verse of a whole book, in order, chapter by chapter.
  /// Paces network requests to stay comfortably under bible-api.com's
  /// 15-requests-per-30-seconds limit (helloao.org has no documented limit,
  /// so it's paced lighter) - already-cached chapters are returned
  /// instantly with no delay and no network call. onProgress reports
  /// (chapters done, chapters total).
  Future<List<BibleVerse>> fetchBook(
    String bookId,
    String translation, {
    int startChapter = 1,
    void Function(int done, int total)? onProgress,
  }) async {
    final total = await chapterCount(bookId, translation);
    if (total == 0) {
      throw Exception('No chapters found for $bookId ($translation).');
    }

    final delay = _usesHelloAo(translation)
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 2200);

    final verses = <BibleVerse>[];
    for (var chapter = startChapter; chapter <= total; chapter++) {
      final alreadyCached = await (await _chapterCacheFile(translation, bookId, chapter)).exists();
      final chapterVerses = await fetchChapter(bookId, chapter, translation);
      verses.addAll(chapterVerses);
      onProgress?.call(chapter - startChapter + 1, total - startChapter + 1);
      if (chapter < total && !alreadyCached) {
        await Future.delayed(delay);
      }
    }
    return verses;
  }
}
