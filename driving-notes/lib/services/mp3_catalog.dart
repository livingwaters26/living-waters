import 'folder_tree.dart';
import 'bible_text_service.dart';

/// One MP3 after reading its filename: book, chapter, narrator.
class CatalogGuess {
  final String title;
  final String translation;
  final String? book;
  final int? chapter;
  final String? narrator;
  final String folderPath;

  const CatalogGuess({
    required this.title,
    required this.translation,
    required this.folderPath,
    this.book,
    this.chapter,
    this.narrator,
  });

  bool get sorted => book != null;
}

/// Turns dump filenames into Translation / Book / Narrator paths.
///
/// Understands names like:
///   BSB_Gilbert-Leviticus-001.mp3
///   GAB_FatherMike-Revelation-001-005.mp3
///   (KJV)-Gilbert_Ruth_003.mp3
///   (ESV)-Drama_Job_3.mp3
///   Job - Chapter 003 (Drama).mp3
///   Ruth - Chapter 003 (Gilbert).mp3
///   40Mat004.mp3
class Mp3Catalog {
  static const _usfmNumber = <int, String>{
    1: 'Genesis',
    2: 'Exodus',
    3: 'Leviticus',
    4: 'Numbers',
    5: 'Deuteronomy',
    6: 'Joshua',
    7: 'Judges',
    8: 'Ruth',
    9: '1 Samuel',
    10: '2 Samuel',
    11: '1 Kings',
    12: '2 Kings',
    13: '1 Chronicles',
    14: '2 Chronicles',
    15: 'Ezra',
    16: 'Nehemiah',
    17: 'Esther',
    18: 'Job',
    19: 'Psalms',
    20: 'Proverbs',
    21: 'Ecclesiastes',
    22: 'Song of Solomon',
    23: 'Isaiah',
    24: 'Jeremiah',
    25: 'Lamentations',
    26: 'Ezekiel',
    27: 'Daniel',
    28: 'Hosea',
    29: 'Joel',
    30: 'Amos',
    31: 'Obadiah',
    32: 'Jonah',
    33: 'Micah',
    34: 'Nahum',
    35: 'Habakkuk',
    36: 'Zephaniah',
    37: 'Haggai',
    38: 'Zechariah',
    39: 'Malachi',
    40: 'Matthew',
    41: 'Mark',
    42: 'Luke',
    43: 'John',
    44: 'Acts',
    45: 'Romans',
    46: '1 Corinthians',
    47: '2 Corinthians',
    48: 'Galatians',
    49: 'Ephesians',
    50: 'Philippians',
    51: 'Colossians',
    52: '1 Thessalonians',
    53: '2 Thessalonians',
    54: '1 Timothy',
    55: '2 Timothy',
    56: 'Titus',
    57: 'Philemon',
    58: 'Hebrews',
    59: 'James',
    60: '1 Peter',
    61: '2 Peter',
    62: '1 John',
    63: '2 John',
    64: '3 John',
    65: 'Jude',
    66: 'Revelation',
  };

  static final _bible = BibleTextService();

  static const _translationAliases = <String, String>{
    'kjv': 'King James Version',
    'king james': 'King James Version',
    'king james version': 'King James Version',
    'niv': 'NIV',
    'esv': 'ESV',
    'bsb': 'Berean Standard Bible',
    'berean': 'Berean Standard Bible',
    'berean standard bible': 'Berean Standard Bible',
    'web': 'World English Bible',
    'world english bible': 'World English Bible',
    'asv': 'American Standard Version (1901)',
    'american standard': 'American Standard Version (1901)',
    'american standard version (1901)': 'American Standard Version (1901)',
    'bbe': 'Bible in Basic English',
    'bible in basic english': 'Bible in Basic English',
    'dra': 'Douay-Rheims 1899',
    'douay': 'Douay-Rheims 1899',
    'rheims': 'Douay-Rheims 1899',
    'douay-rheims 1899': 'Douay-Rheims 1899',
    'gab': 'Great Adventure Bible',
    'great adventure': 'Great Adventure Bible',
    'great adventure bible': 'Great Adventure Bible',
    'nlt': 'NLT',
    'nasb': 'NASB',
    'nkjv': 'NKJV',
    'csb': 'CSB',
    'msg': 'MSG',
  };

  /// Same as [parse] but also looks at parent folders:
  /// `.../10 - BSB_Gilbert-2 Samuel/BSB_Gilbert-2 Samuel-001.mp3`
  /// and `.../Berean Standard Bible (Gilbert)/...`.
  static CatalogGuess parsePath(String filePath, {required String translation}) {
    final name = filePath.replaceAll('\\', '/').split('/').last;
    var guess = parse(name, translation: translation);
    final parts = filePath.replaceAll('\\', '/').split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      for (final part in parts.reversed.skip(1).take(5)) {
        final cleaned = part.replaceFirst(RegExp(r'^\d{1,2}\s*-\s*'), '');
        final fromFolder = parse(cleaned, translation: guess.translation);
        if (guess.book == null && fromFolder.book != null) {
          guess = CatalogGuess(
            title: guess.title,
            translation: fromFolder.translation,
            book: fromFolder.book,
            chapter: guess.chapter ?? fromFolder.chapter,
            narrator: guess.narrator ?? fromFolder.narrator,
            folderPath: '',
          );
        } else if (guess.narrator == null && fromFolder.narrator != null) {
          guess = CatalogGuess(
            title: guess.title,
            translation: guess.translation,
            book: guess.book,
            chapter: guess.chapter,
            narrator: fromFolder.narrator,
            folderPath: '',
          );
        }
        final folderNar = _narratorFrom(part);
        if (guess.narrator == null && folderNar != null) {
          guess = CatalogGuess(
            title: guess.title,
            translation: guess.translation,
            book: guess.book,
            chapter: guess.chapter,
            narrator: folderNar,
            folderPath: '',
          );
        }
      }
    }
    var path = FolderTree.normalize(guess.translation);
    if (path.isEmpty) path = 'Unsorted';
    if (guess.book != null) {
      path = FolderTree.join(path, guess.book!);
      if (guess.narrator != null) path = FolderTree.join(path, guess.narrator!);
    } else {
      path = FolderTree.join(path, 'Unsorted');
    }
    return CatalogGuess(
      title: guess.title,
      translation: guess.translation,
      book: guess.book,
      chapter: guess.chapter,
      narrator: guess.narrator,
      folderPath: path,
    );
  }

  static CatalogGuess parse(String filename, {required String translation}) {
    var title = filename.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    title = title.replaceFirst(RegExp(r'^\d{1,2}\s*-\s*'), '');
    final labeled = _parseCodePrefix(title) ?? _parseLabeled(title);
    final usedTranslation = labeled?.translation ?? _mapTranslation(translation) ?? translation;
    final narrator = labeled?.narrator ?? _narratorFrom(title);
    final chapter = labeled?.chapter ?? _chapterFrom(title);
    final book = labeled?.book ?? _bookFrom(title);
    var path = FolderTree.normalize(usedTranslation);
    if (path.isEmpty) path = 'Unsorted';
    if (book != null) {
      path = FolderTree.join(path, book);
      if (narrator != null) path = FolderTree.join(path, narrator);
    } else {
      path = FolderTree.join(path, 'Unsorted');
    }
    return CatalogGuess(
      title: title,
      translation: usedTranslation,
      book: book,
      chapter: chapter,
      narrator: narrator,
      folderPath: path,
    );
  }

  /// `BSB_Gilbert-Leviticus-001` or `GAB_FatherMike-Revelation-001-005`
  static ({String translation, String? narrator, String? book, int? chapter})? _parseCodePrefix(String title) {
    final match = RegExp(r'^([A-Za-z]{2,8})[_-](.+)$').firstMatch(title);
    if (match == null) return null;
    final translation = _mapTranslation(match.group(1)!);
    if (translation == null) return null;
    return _splitNarratorBookChapter(translation, match.group(2)!.trim());
  }

  /// `(KJV)-Gilbert_Ruth_003` or `(ESV)-Father Mike_1_Samuel_12`
  static ({String translation, String? narrator, String? book, int? chapter})? _parseLabeled(String title) {
    final match = RegExp(r'^\(([^)]+)\)\s*-?\s*(.+)$').firstMatch(title);
    if (match == null) return null;
    final translation = _mapTranslation(match.group(1)!) ?? match.group(1)!.trim();
    return _splitNarratorBookChapter(translation, match.group(2)!.trim());
  }

  static ({String translation, String? narrator, String? book, int? chapter}) _splitNarratorBookChapter(
    String translation,
    String rest,
  ) {
    int? chapter;
    final chapterTail = RegExp(r'[_ \-]+(\d{1,3})(?:[_ \-]+(\d{1,3}))?\s*$').firstMatch(rest);
    if (chapterTail != null) {
      chapter = int.tryParse(chapterTail.group(1)!);
      rest = rest.substring(0, chapterTail.start).trim();
      rest = rest.replaceFirst(RegExp(r'[_ \-]+chapter$', caseSensitive: false), '');
    }
    final bookHit = _bookAtEnd(rest);
    if (bookHit == null) {
      return (
        translation: translation,
        narrator: rest.isEmpty ? null : _prettyNarrator(rest),
        book: null,
        chapter: chapter,
      );
    }
    var narrator = rest.substring(0, rest.length - bookHit.matchedLength).trim();
    narrator = narrator.replaceFirst(RegExp(r'[_\-\s]+$'), '');
    return (
      translation: translation,
      narrator: narrator.isEmpty ? null : _prettyNarrator(narrator),
      book: bookHit.book,
      chapter: chapter,
    );
  }

  static String _prettyNarrator(String raw) {
    var name = raw.replaceAll('_', ' ').trim();
    name = name.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
    return name;
  }

  static ({String book, int matchedLength})? _bookAtEnd(String text) {
    final names = <String>{
      ...BibleTextService.bookOrder,
      ...BibleTextService.catholicBookOrder,
      ...BibleTextService.apocryphaBooks,
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final lowered = text.toLowerCase();
    for (final name in names) {
      for (final form in _bookForms(name)) {
        if (lowered == form) return (book: name, matchedLength: text.length);
        if (lowered.endsWith('_$form') ||
            lowered.endsWith('-$form') ||
            lowered.endsWith(' $form')) {
          return (book: name, matchedLength: form.length + 1);
        }
      }
    }
    return null;
  }

  /// All usual ways a book shows up in a dump name. No rename required.
  static Iterable<String> _bookForms(String name) {
    final lower = name.toLowerCase();
    final jammed = lower.replaceAll(' ', '');
    final forms = <String>{
      lower,
      jammed,
      lower.replaceAll(' ', '_'),
      lower.replaceAll(' ', '-'),
    };
    final numbered = RegExp(r'^([123])\s+(.+)$').firstMatch(lower);
    if (numbered != null) {
      final n = numbered.group(1)!;
      final rest = numbered.group(2)!;
      final jammedRest = rest.replaceAll(' ', '');
      final ordinal = n == '1' ? ['1st', 'first', 'i'] : n == '2' ? ['2nd', 'second', 'ii'] : ['3rd', 'third', 'iii'];
      for (final word in [n, ...ordinal]) {
        forms.addAll([
          '$word $rest',
          '$word$jammedRest',
          '$word-$rest',
          '$word-$jammedRest',
          '${word}_$rest',
          '$word $jammedRest',
        ]);
      }
    }
    return forms.map((f) => f.toLowerCase());
  }

  static String? _mapTranslation(String raw) {
    final key = raw.trim().toLowerCase();
    return _translationAliases[key];
  }

  static String? _narratorFrom(String title) {
    final match = RegExp(r'\(([^)]+)\)\s*$').firstMatch(title);
    if (match == null) return null;
    final name = match.group(1)!.trim();
    if (name.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(name)) return null;
    if (_mapTranslation(name) != null) return null;
    return name;
  }

  static int? _chapterFrom(String title) {
    final labeled = RegExp(r'chapter\s+(\d+)', caseSensitive: false).firstMatch(title);
    if (labeled != null) return int.tryParse(labeled.group(1)!);
    final usfm = RegExp(r'^\d{1,2}[A-Za-z]{2,4}(\d{2,3})\b').firstMatch(title);
    if (usfm != null) return int.tryParse(usfm.group(1)!);
    final tail = RegExp(r'[_ \-](\d+)\s*$').firstMatch(title);
    if (tail != null) return int.tryParse(tail.group(1)!);
    return null;
  }

  static String? _bookFrom(String title) {
    final usfm = RegExp(r'^(\d{1,2})([A-Za-z]{2,4})(\d{2,3})\b').firstMatch(title);
    if (usfm != null) {
      final number = int.tryParse(usfm.group(1)!);
      if (number != null && _usfmNumber.containsKey(number)) {
        return _usfmNumber[number];
      }
      final fromLetters = _bible.findBookId(usfm.group(2)!);
      if (fromLetters != null) return _bible.bookNameForId(fromLetters);
    }
    final stripped = title.replaceFirst(RegExp(r'^\([^)]+\)\s*-?\s*'), '');
    final id = _bible.findBookId(stripped);
    if (id == null) return null;
    return _bible.bookNameForId(id);
  }

  static int compareTitles(String a, String b) {
    final left = parse(a, translation: 'x');
    final right = parse(b, translation: 'x');
    final bookRank = _bookRank(left.book).compareTo(_bookRank(right.book));
    if (bookRank != 0) return bookRank;
    final chapterRank = (left.chapter ?? 0).compareTo(right.chapter ?? 0);
    if (chapterRank != 0) return chapterRank;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static int _bookRank(String? book) {
    if (book == null) return 9999;
    final index = BibleTextService.folderSortOrder.indexOf(book);
    return index < 0 ? 1000 : index;
  }
}
