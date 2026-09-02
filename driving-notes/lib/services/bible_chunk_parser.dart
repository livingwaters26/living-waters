import 'bible_text_service.dart';

class ParsedVerse {
  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  const ParsedVerse({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get key => '$bookId|$chapter|$verse';
}

class ParseChunkResult {
  final List<ParsedVerse> verses;
  final int duplicateInFile;
  final List<String> skippedHints;
  final String sample;

  const ParseChunkResult({
    required this.verses,
    required this.duplicateInFile,
    required this.skippedHints,
    this.sample = '',
  });
}

class BibleChunkParser {
  final _bible = BibleTextService();

  static final _nasbHeader = RegExp(
    r'^(.+?)\s+(\d{1,3})\s+New American Standard Bible$',
    caseSensitive: false,
  );
  static final _refLine = RegExp(
    r'^(.+?)\s+(\d{1,3}):(\d{1,3})\s+(.+)$',
  );
  static final _esvRef = RegExp(r'^(\d{1,3}):(\d{1,3})\s+(.*)$');
  static final _chapterLine = RegExp(r'^Chapter\s+(\d{1,3})$', caseSensitive: false);
  static final _loneNumber = RegExp(r'^\d{1,3}$');
  static final _chapterStuck = RegExp(r'^(\d{1,3})([A-Za-z“"‘].+)$');
  static final _verseSpaced = RegExp(r'^(\d{1,3})[.)]?\s+(.+)$');
  static final _inlineVerse = RegExp(r'(\d{1,3})(?=[A-Z“"‘])');

  ParseChunkResult parse(String raw) {
    final byKey = <String, ParsedVerse>{};
    var dupes = 0;
    final normalized = raw
        .replaceAll('\u000c', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final sample = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sampleShort = sample.length <= 400 ? sample : sample.substring(0, 400);

    void add(ParsedVerse pv) {
      var text = pv.text.replaceAll(RegExp(r'\[[0-9]+\]'), '').trim();
      if (text.isEmpty) return;
      final clean = ParsedVerse(
        bookId: pv.bookId,
        bookName: pv.bookName,
        chapter: pv.chapter,
        verse: pv.verse,
        text: text,
      );
      if (byKey.containsKey(clean.key)) dupes++;
      byKey[clean.key] = clean;
    }

    _parseLines(normalized, add, byKey);

    return ParseChunkResult(
      verses: byKey.values.toList(),
      duplicateInFile: dupes,
      skippedHints: byKey.isEmpty
          ? ['No verses found. Start: ${sampleShort.isEmpty ? "(empty)" : sampleShort}']
          : const [],
      sample: sampleShort,
    );
  }

  String _normTitle(String raw) {
    var t = raw.trim().toLowerCase();
    t = t.replaceAll('_', ' ').replaceAll('-', ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceFirst(RegExp(r'^(1st|first)\s+'), '1 ');
    t = t.replaceFirst(RegExp(r'^(2nd|second)\s+'), '2 ');
    t = t.replaceFirst(RegExp(r'^(3rd|third)\s+'), '3 ');
    return t;
  }

  bool _isBookTitleLine(String line) {
    if (line.isEmpty || line.length > 24) return false;
    final t = _normTitle(line);
    final id = _bible.findBookId(t);
    if (id == null) return false;
    final name = (_bible.bookNameForId(id) ?? '').toLowerCase();
    return name == t;
  }

  void _splitAndAdd({
    required void Function(ParsedVerse) add,
    required String bookId,
    required String bookName,
    required int chapter,
    required int startVerse,
    required String rest,
  }) {
    final matches = _inlineVerse.allMatches(rest).toList();
    if (matches.isEmpty) {
      add(ParsedVerse(
        bookId: bookId,
        bookName: bookName,
        chapter: chapter,
        verse: startVerse,
        text: rest,
      ));
      return;
    }
    var verse = startVerse;
    var from = 0;
    for (final m in matches) {
      final chunk = rest.substring(from, m.start).trim();
      if (chunk.isNotEmpty) {
        add(ParsedVerse(
          bookId: bookId,
          bookName: bookName,
          chapter: chapter,
          verse: verse,
          text: chunk,
        ));
      }
      verse = int.parse(m.group(1)!);
      from = m.end;
    }
    final tail = rest.substring(from).trim();
    if (tail.isNotEmpty) {
      add(ParsedVerse(
        bookId: bookId,
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        text: tail,
      ));
    }
  }

  void _parseLines(
    String raw,
    void Function(ParsedVerse) add,
    Map<String, ParsedVerse> byKey,
  ) {
    String? bookId;
    String? bookName;
    int? chapter;
    String? lastKey;
    int? pendingVerse;
    var inFootnotes = false;

    void remember(ParsedVerse pv) {
      add(pv);
      lastKey = pv.key;
      pendingVerse = null;
    }

    void append(String extra) {
      if (lastKey == null || !byKey.containsKey(lastKey)) return;
      final prev = byKey[lastKey]!;
      byKey[lastKey!] = ParsedVerse(
        bookId: prev.bookId,
        bookName: prev.bookName,
        chapter: prev.chapter,
        verse: prev.verse,
        text: '${prev.text} $extra',
      );
    }

    for (final original in raw.split('\n')) {
      var line = original.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (line.isEmpty) continue;
      if (line.toLowerCase() == 'footnotes') {
        inFootnotes = true;
        continue;
      }
      if (line.toLowerCase().contains('all rights reserved')) continue;

      if (_isBookTitleLine(line)) {
        inFootnotes = false;
        final id = _bible.findBookId(_normTitle(line))!;
        bookId = id;
        bookName = _bible.bookNameForId(id) ?? line;
        chapter = null;
        lastKey = null;
        pendingVerse = null;
        continue;
      }

      if (inFootnotes) continue;

      final ref = _refLine.firstMatch(line);
      if (ref != null) {
        final id = _bible.findBookId(ref.group(1)!);
        if (id != null) {
          bookId = id;
          bookName = _bible.bookNameForId(id) ?? ref.group(1)!.trim();
          chapter = int.parse(ref.group(2)!);
          remember(ParsedVerse(
            bookId: bookId,
            bookName: bookName!,
            chapter: chapter!,
            verse: int.parse(ref.group(3)!),
            text: ref.group(4)!.trim(),
          ));
          continue;
        }
      }

      final nasb = _nasbHeader.firstMatch(line);
      if (nasb != null) {
        final id = _bible.findBookId(nasb.group(1)!);
        if (id != null) {
          bookId = id;
          bookName = _bible.bookNameForId(id) ?? nasb.group(1)!.trim();
          chapter = int.parse(nasb.group(2)!);
          lastKey = null;
          pendingVerse = null;
          continue;
        }
      }

      final chapLine = _chapterLine.firstMatch(line);
      if (chapLine != null) {
        if (bookId != null) chapter = int.parse(chapLine.group(1)!);
        continue;
      }

      if (bookId == null) continue;

      final esv = _esvRef.firstMatch(line);
      if (esv != null) {
        chapter = int.parse(esv.group(1)!);
        _splitAndAdd(
          add: remember,
          bookId: bookId,
          bookName: bookName ?? bookId,
          chapter: chapter!,
          startVerse: int.parse(esv.group(2)!),
          rest: esv.group(3)!,
        );
        continue;
      }

      final stuck = _chapterStuck.firstMatch(line);
      if (stuck != null) {
        final n = int.parse(stuck.group(1)!);
        final rest = stuck.group(2)!.trim();
        if (chapter == null || n == (chapter + 1) || lastKey == null) {
          chapter = n;
          _splitAndAdd(
            add: remember,
            bookId: bookId,
            bookName: bookName ?? bookId,
            chapter: n,
            startVerse: 1,
            rest: rest,
          );
        } else {
          _splitAndAdd(
            add: remember,
            bookId: bookId,
            bookName: bookName ?? bookId,
            chapter: chapter,
            startVerse: n,
            rest: rest,
          );
        }
        continue;
      }

      if (_loneNumber.hasMatch(line)) {
        pendingVerse = int.parse(line);
        chapter ??= 1;
        continue;
      }

      final spaced = _verseSpaced.firstMatch(line);
      if (spaced != null) {
        chapter ??= 1;
        _splitAndAdd(
          add: remember,
          bookId: bookId,
          bookName: bookName ?? bookId,
          chapter: chapter,
          startVerse: int.parse(spaced.group(1)!),
          rest: spaced.group(2)!,
        );
        continue;
      }

      if (pendingVerse != null) {
        chapter ??= 1;
        remember(ParsedVerse(
          bookId: bookId,
          bookName: bookName ?? bookId,
          chapter: chapter,
          verse: pendingVerse!,
          text: line,
        ));
        continue;
      }

      if (lastKey != null && line.length > 1) append(line);
    }
  }

  static String extractPdfText(List<int> bytes) {
    final out = StringBuffer();
    final latin = String.fromCharCodes(bytes.map((b) {
      if (b == 10 || b == 13 || (b >= 32 && b < 127)) return b;
      return 32;
    }));
    final tj = RegExp(r'\((?:\\.|[^\\)])*\)\s*Tj');
    for (final m in tj.allMatches(latin)) {
      var s = m.group(0)!;
      s = s.substring(1, s.lastIndexOf(')'));
      out.writeln(s);
    }
    return out.length > 80 ? out.toString() : latin;
  }
}
