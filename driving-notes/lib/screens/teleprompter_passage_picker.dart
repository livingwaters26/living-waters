import 'package:flutter/material.dart';

import '../services/bible_text_service.dart';

/// What was picked in TeleprompterPassagePicker - a display label plus the
/// text already broken into numbered chunks, ready to hand straight to the
/// Record a Reading teleprompter view. [verses] is reused from the Bible
/// text model even for non-scripture text - each chunk just becomes a
/// sequentially-numbered "verse" with no real book/chapter behind it, so
/// the teleprompter's rendering/scrolling code doesn't need to know or
/// care where the text came from.
class TeleprompterPassage {
  final String label;
  final List<BibleVerse> verses;

  const TeleprompterPassage({
    required this.label,
    required this.verses,
  });
}

/// Lets you load either a real scripture passage OR your own pasted/typed
/// text into the Record a Reading teleprompter - this isn't just for
/// scripture; it works just as well as a lightweight teaching-notes or
/// lesson-script prompter for anything you record ahead of time.
class TeleprompterPassagePicker extends StatefulWidget {
  const TeleprompterPassagePicker({super.key});

  @override
  State<TeleprompterPassagePicker> createState() => _TeleprompterPassagePickerState();
}

class _TeleprompterPassagePickerState extends State<TeleprompterPassagePicker> {
  static const _translation = 'bsb';
  final _bibleText = BibleTextService();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _customTextController = TextEditingController();

  // null = choosing between scripture/custom text; 'scripture' or 'custom'
  // once a path is picked.
  String? _mode;

  String? _selectedBook;
  int? _chapterCount;
  bool _loadingChapters = false;
  bool _loadingPassage = false;

  List<String> get _filteredBooks {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return BibleTextService.bookOrder;
    return BibleTextService.bookOrder.where((b) => b.toLowerCase().contains(q)).toList();
  }

  Future<void> _selectBook(String book) async {
    setState(() {
      _selectedBook = book;
      _chapterCount = null;
      _loadingChapters = true;
    });
    try {
      final bookId = _bibleText.bookIdFor(book);
      final count = await _bibleText.chapterCount(bookId, _translation);
      if (mounted && _selectedBook == book) {
        setState(() {
          _chapterCount = count;
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
    });
  }

  Future<void> _pickChapter(int chapter) async {
    final book = _selectedBook;
    if (book == null || _loadingPassage) return;
    setState(() => _loadingPassage = true);
    try {
      final bookId = _bibleText.bookIdFor(book);
      final verses = await _bibleText.fetchChapter(bookId, chapter, _translation);
      if (!mounted) return;
      Navigator.of(context).pop(
        TeleprompterPassage(label: '$book $chapter', verses: verses),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPassage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load $book $chapter: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  /// Splits pasted/typed text into chunks the teleprompter can scroll
  /// through one at a time - blank-line-separated paragraphs by default
  /// (matches how most notes/scripts are naturally written), falling back
  /// to one chunk per line if there's no blank-line structure at all (e.g.
  /// text pasted from somewhere that collapsed the paragraph breaks).
  List<BibleVerse> _buildCustomVerses(String rawText) {
    final paragraphs = rawText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final chunks = paragraphs.length > 1
        ? paragraphs
        : rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (chunks.isEmpty) return [BibleVerse(book: '', chapter: 1, verse: 1, text: rawText.trim())];
    return [
      for (var i = 0; i < chunks.length; i++)
        BibleVerse(book: '', chapter: 1, verse: i + 1, text: chunks[i]),
    ];
  }

  void _useCustomText() {
    final raw = _customTextController.text;
    if (raw.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste or type something first.')),
      );
      return;
    }
    final title = _titleController.text.trim();
    Navigator.of(context).pop(
      TeleprompterPassage(
        label: title.isEmpty ? 'Custom Reading' : title,
        verses: _buildCustomVerses(raw),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == null) return _buildModeChooser(context);
    if (_mode == 'custom') return _buildCustomTextEntry(context);
    final book = _selectedBook;
    if (book != null) return _buildChapterPicker(context, book);
    return _buildBookPicker(context);
  }

  Widget _buildModeChooser(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Load a Passage')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What do you want scrolling on screen while you record?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                leading: Icon(Icons.menu_book, size: 34, color: theme.colorScheme.primary),
                title: const Text('Scripture Passage', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Pick a book and chapter - the real text loads automatically.'),
                trailing: const Icon(Icons.chevron_right, size: 32),
                onTap: () => setState(() => _mode = 'scripture'),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                leading: Icon(Icons.description, size: 34, color: theme.colorScheme.primary),
                title: const Text('Your Own Text', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Paste or type notes, a lesson outline, a teaching script - anything.'),
                trailing: const Icon(Icons.chevron_right, size: 32),
                onTap: () => setState(() => _mode = 'custom'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextEntry(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => setState(() => _mode = null),
        ),
        title: const Text('Your Own Text'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'e.g. Week 3 - Romans Overview',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _customTextController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Paste or type your notes/script',
                    hintText: 'Tip: leave a blank line between sections so they '
                        'scroll as separate chunks.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _useCustomText,
                  icon: const Icon(Icons.check),
                  label: const Text('Use This Text'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => setState(() => _mode = null),
        ),
        title: const Text('Load a Passage'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick what you\'re about to read - it\'ll scroll on screen while you record.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
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
          onPressed: _loadingPassage ? null : _backToBooks,
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
                    Text(
                      _chapterCount == null
                          ? 'Chapters'
                          : 'Chapters (1-$_chapterCount) - tap one to load it',
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
                          return ElevatedButton(
                            onPressed: _loadingPassage ? null : () => _pickChapter(chapter),
                            style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(
                              '$chapter',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_loadingPassage) ...[
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
