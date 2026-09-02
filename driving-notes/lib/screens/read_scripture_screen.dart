import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/simple_storage.dart';
import 'import_bible_screen.dart';
import 'tts_player_screen.dart';

/// Reached from the "Read Scripture" button on the home screen. Two steps:
/// pick a translation + book from a list, then pick a chapter from a grid
/// of tappable numbers (with a "Resume" option up top if you've already
/// made progress in that book) - then it jumps straight into a
/// text-to-speech reading session, no MP3 file needed.
class ReadScriptureScreen extends StatefulWidget {
  // Skips the book list and jumps straight to this book's chapter picker -
  // used when arriving here via a guessed book name (e.g. from the "this
  // looks like scripture, read it instead of transcribing" prompt on an
  // imported MP3's caption warning) instead of picking one by hand.
  final String? initialBook;

  const ReadScriptureScreen({super.key, this.initialBook});

  @override
  State<ReadScriptureScreen> createState() => _ReadScriptureScreenState();
}

class _ReadScriptureScreenState extends State<ReadScriptureScreen> {
  final _storage = SimpleStorage();
  final _bibleText = BibleTextService();
  final _searchController = TextEditingController();

  String _translation = 'bsb';
  String? _selectedBook;
  bool _starting = false;
  Map<String, String> _translations = BibleTextService.translations;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    if (widget.initialBook != null) {
      _selectBook(widget.initialBook!);
    }
  }

  Future<void> _loadTranslations() async {
    final map = await BibleTextService.allTranslations();
    if (!mounted) return;
    setState(() => _translations = map);
  }

  Future<void> _openImportChunk() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportBibleScreen()),
    );
    await _loadTranslations();
  }

  // Chapter-picker state for whichever book is currently selected.
  int? _chapterCount;
  bool _loadingChapters = false;
  AudioFile? _progress; // saved lastChapter/lastVerse for this book+translation, if any

  List<String> get _filteredBooks {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return BibleTextService.bookOrder;
    return BibleTextService.bookOrder.where((b) => b.toLowerCase().contains(q)).toList();
  }

  /// Looks up how many chapters this book has (cached after the first time,
  /// so this is instant/offline for anything read before) and whatever
  /// reading progress is already saved for it.
  Future<void> _selectBook(String book) async {
    setState(() {
      _selectedBook = book;
      _chapterCount = null;
      _progress = null;
      _loadingChapters = true;
    });
    try {
      final bookId = _bibleText.bookIdFor(book);
      final count = await _bibleText.chapterCount(bookId, _translation);
      final path = 'tts:$_translation:$bookId';
      final files = await _storage.loadAudioFiles();
      final existing = files.cast<AudioFile?>().firstWhere(
            (f) => f?.path == path,
            orElse: () => null,
          );
      if (mounted && _selectedBook == book) {
        setState(() {
          _chapterCount = count;
          _progress = (existing != null && existing.lastChapter > 0) ? existing : null;
          _loadingChapters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingChapters = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check chapters for $book: $e')),
        );
      }
    }
  }

  void _backToBooks() {
    setState(() {
      _selectedBook = null;
      _chapterCount = null;
      _progress = null;
    });
  }

  /// Starts (or resumes) reading at an exact chapter/verse - tapping any
  /// chapter number always starts fresh at verse 1 of that chapter
  /// (verse is only ever non-null via the "Resume" button up top).
  Future<void> _startAt(int chapter, {int? verse}) async {
    final book = _selectedBook;
    if (book == null || _starting) return;
    setState(() => _starting = true);

    try {
      final bookId = _bibleText.bookIdFor(book);
      final translationLabel = _translations[_translation] ??
          BibleTextService.translations[_translation] ??
          _translation;
      final title = '$book ($translationLabel)';
      // Deliberately NOT keyed by starting chapter - one book+translation
      // should always resolve to the same progress, however you started it
      // last time.
      final path = 'tts:$_translation:$bookId';

      final files = await _storage.loadAudioFiles();
      var audioFile = files.cast<AudioFile?>().firstWhere(
            (f) => f?.path == path,
            orElse: () => null,
          );
      if (audioFile == null) {
        audioFile = AudioFile(path: path, title: title, duration: Duration.zero);
        await _storage.addAudioFile(audioFile);
      }

      final now = DateTime.now();
      final session = Session(
        audioFileId: audioFile.id,
        label: '$title – ${now.month}/${now.day}/${now.year}',
      );
      await _storage.addSession(session);

      if (!mounted) return;
      // A normal push (not pushReplacement) - so the back button on the
      // reading screen returns here to pick a different chapter instead of
      // skipping straight past this screen.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TtsPlayerScreen(
            audioFileId: audioFile!.id,
            sessionId: session.id,
            sessionLabel: session.label,
            bookName: book,
            bookId: bookId,
            translation: _translation,
            startChapter: chapter,
            startVerse: verse,
          ),
        ),
      );
      if (mounted) {
        setState(() => _starting = false);
        // Refresh progress in case reading moved on while that screen was open.
        unawaited(_selectBook(book));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = _selectedBook;
    if (book != null) {
      return _buildChapterPicker(context, book);
    }
    return _buildBookPicker(context);
  }

  Widget _buildBookPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Scripture'),
        actions: [
          TextButton.icon(
            onPressed: _openImportChunk,
            icon: const Icon(Icons.post_add),
            label: const Text('Import chunk'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Picks up the real text and reads it aloud - no MP3 needed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _translations.containsKey(_translation) ? _translation : _translations.keys.first,
              decoration: const InputDecoration(
                labelText: 'Translation',
                border: OutlineInputBorder(),
              ),
              items: _translations.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _translation = v ?? _translation),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openImportChunk,
              icon: const Icon(Icons.upload_file),
              label: const Text('Add title / Import chunk'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search books',
                hintText: 'e.g. John, Exodus, Psalms',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      title: Text(book, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right, size: 32),
                      onTap: () => _selectBook(book),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterPicker(BuildContext context, String book) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to books',
          onPressed: _starting ? null : _backToBooks,
        ),
        title: Text(book),
      ),
      body: SafeArea(
        child: _loadingChapters
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_progress != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _starting
                              ? null
                              : () => _startAt(_progress!.lastChapter, verse: _progress!.lastVerse),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 88),
                            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          icon: const Icon(Icons.play_circle_fill, size: 40),
                          label: Text('Resume – ${_progress!.lastChapter}:${_progress!.lastVerse}'),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      _chapterCount == null
                          ? 'Chapters'
                          : 'Chapters (1–$_chapterCount) - tap one to start there',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: _chapterCount ?? 0,
                        itemBuilder: (context, index) {
                          final chapter = index + 1;
                          final isCurrent = _progress != null && _progress!.lastChapter == chapter;
                          return ElevatedButton(
                            onPressed: _starting ? null : () => _startAt(chapter),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: isCurrent ? theme.colorScheme.primary : null,
                              foregroundColor: isCurrent ? theme.colorScheme.onPrimary : null,
                            ),
                            child: Text(
                              '$chapter',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_starting) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
