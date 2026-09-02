import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/bible_text_service.dart';
import '../services/export_service.dart';
import '../services/simple_storage.dart';
import 'sessions_screen.dart';

/// Every note you've taken, from every book/file, in one place - grouped
/// by day (today at the top). Built so you don't have to remember which
/// book or file a note lives in to find it again: after a commute where
/// you took a note in Daniel and another in Jeremiah, this is where both
/// show up together instead of having to dig through each book/file
/// separately.
///
/// Within a day you can look at notes two ways: **By book** (the default -
/// every note from the same book/file collected together, books in normal
/// Bible order) or **By time** (one straight chronological run, newest
/// first - the original behavior).
class TodaysNotesScreen extends StatefulWidget {
  const TodaysNotesScreen({super.key});

  @override
  State<TodaysNotesScreen> createState() => _TodaysNotesScreenState();
}

/// All the notes from one book/file on one particular day, oldest first -
/// reading a book's notes in the order you actually took them tells the
/// story of that sitting better than newest-first does.
class _BookGroup {
  final String audioFileId;
  final String audioTitle;
  final List<NoteWithSource> entries;
  _BookGroup({required this.audioFileId, required this.audioTitle, required this.entries});
}

class _DayGroup {
  final DateTime day;
  final List<NoteWithSource> entries; // flat, newest first
  final List<_BookGroup> books; // same notes, collected by book/file
  _DayGroup({required this.day, required this.entries, required this.books});
}

class _TodaysNotesScreenState extends State<TodaysNotesScreen> {
  final _storage = SimpleStorage();
  final _export = ExportService();
  final _bibleText = BibleTextService();
  bool _loading = true;
  bool _groupByBook = true;
  List<_DayGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Where a title falls in normal Bible order, so a day's books read
  /// Genesis -> Revelation instead of alphabetically or at random. Anything
  /// that isn't a recognizable book (a sermon, a personal recording) sorts
  /// after all the scripture, alphabetically among itself.
  int _bookRank(String title) {
    final id = _bibleText.findBookId(title);
    if (id == null) return 1000;
    final name = _bibleText.bookNameForId(id);
    if (name == null) return 1000;
    final idx = BibleTextService.bookOrder.indexOf(name);
    return idx < 0 ? 1000 : idx;
  }

  List<_BookGroup> _groupIntoBooks(List<NoteWithSource> dayEntries) {
    final byFile = <String, _BookGroup>{};
    for (final entry in dayEntries) {
      final group = byFile.putIfAbsent(
        entry.audioFileId,
        () => _BookGroup(
          audioFileId: entry.audioFileId,
          audioTitle: entry.audioTitle,
          entries: [],
        ),
      );
      group.entries.add(entry);
    }
    final books = byFile.values.toList();
    for (final b in books) {
      // Oldest first inside a book - follows how the sitting actually went.
      b.entries.sort((x, y) => x.note.createdAt.compareTo(y.note.createdAt));
    }
    books.sort((a, b) {
      final rank = _bookRank(a.audioTitle).compareTo(_bookRank(b.audioTitle));
      if (rank != 0) return rank;
      return a.audioTitle.toLowerCase().compareTo(b.audioTitle.toLowerCase());
    });
    return books;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final notes = await _storage.loadNotes();
    final sessions = await _storage.loadSessions();
    final audioFiles = await _storage.loadAudioFiles();
    final sessionById = {for (final s in sessions) s.id: s};
    final audioFileById = {for (final a in audioFiles) a.id: a};

    final entries = <NoteWithSource>[];
    for (final note in notes) {
      if (!note.isComplete) continue; // self-healed on launch, but skip defensively
      final session = sessionById[note.sessionId];
      if (session == null) continue; // orphaned note - shouldn't normally happen
      final audioFile = audioFileById[session.audioFileId];
      if (audioFile == null) continue;
      entries.add(NoteWithSource(
        note: note,
        audioFileId: audioFile.id,
        audioTitle: audioFile.title,
      ));
    }
    // loadNotes() already sorts newest-first.

    final byDay = <DateTime, List<NoteWithSource>>{};
    final dayOrder = <DateTime>[];
    for (final entry in entries) {
      final d = entry.note.createdAt;
      final day = DateTime(d.year, d.month, d.day);
      if (!byDay.containsKey(day)) {
        byDay[day] = [];
        dayOrder.add(day);
      }
      byDay[day]!.add(entry);
    }

    final groups = [
      for (final day in dayOrder)
        _DayGroup(
          day: day,
          entries: byDay[day]!,
          books: _groupIntoBooks(byDay[day]!),
        ),
    ];

    if (mounted) {
      setState(() {
        _groups = groups;
        _loading = false;
      });
    }
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${day.month}/${day.day}/${day.year}';
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  List<NoteWithSource> get _allVisible => _groups.expand((g) => g.entries).toList();

  Future<void> _shareFile(String fileName, String content) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsString(content);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, name: fileName)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export: $e')),
        );
      }
    }
  }

  Future<void> _exportAll() async {
    final visible = _allVisible;
    if (visible.isEmpty) return;
    await _shareFile(_export.safeAllNotesFileName(), _export.allNotesDigest(visible));
  }

  Future<void> _exportOne(NoteWithSource entry) async {
    await _shareFile(_export.safeNoteFileName(entry), _export.singleNoteText(entry));
  }

  /// Exports just one book's notes from one day - the natural unit when
  /// you've been reading through a single book and want that sitting's
  /// notes on their own.
  Future<void> _exportBook(_BookGroup book) async {
    if (book.entries.isEmpty) return;
    await _shareFile(_export.safeAllNotesFileName(), _export.allNotesDigest(book.entries));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Notes"),
        actions: [
          if (!_loading && _allVisible.isNotEmpty) ...[
            IconButton(
              icon: Icon(_groupByBook ? Icons.menu_book : Icons.schedule),
              tooltip: _groupByBook ? 'Grouped by book - tap for time order' : 'In time order - tap to group by book',
              onPressed: () => setState(() => _groupByBook = !_groupByBook),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export all notes to a text file',
              onPressed: _exportAll,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No notes yet. Notes you take while listening or reading - from any '
                      'book or file - will show up here together, grouped by day.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Text(
                              '${_dayLabel(group.day)}  ·  ${group.entries.length} '
                              'note${group.entries.length == 1 ? '' : 's'}'
                              '${_groupByBook ? '  ·  ${group.books.length} book${group.books.length == 1 ? '' : 's'}' : ''}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_groupByBook)
                            for (final book in group.books) ...[
                              _buildBookHeader(theme, book),
                              for (final entry in book.entries)
                                _buildNoteCard(theme, entry, showTitle: false),
                              const SizedBox(height: 10),
                            ]
                          else
                            for (final entry in group.entries)
                              _buildNoteCard(theme, entry, showTitle: true),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildBookHeader(ThemeData theme, _BookGroup book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
      child: Row(
        children: [
          Icon(Icons.menu_book, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              book.audioTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${book.entries.length}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20),
            tooltip: 'Export this book\'s notes from this day',
            onPressed: () => _exportBook(book),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(ThemeData theme, NoteWithSource entry, {required bool showTitle}) {
    return Card(
      margin: EdgeInsets.only(bottom: 8, left: showTitle ? 0 : 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionsScreen(
              audioFileId: entry.audioFileId,
              title: entry.audioTitle,
            ),
          ),
        ),
        title: Text(entry.note.text, maxLines: 4, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Redundant when every card under a book header shares the
              // same title - dropped there to keep the grouped view clean.
              if (showTitle)
                Text(
                  entry.audioTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (entry.note.captionContext.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '"${entry.note.captionContext}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(_timeLabel(entry.note.createdAt), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        isThreeLine: showTitle,
        trailing: IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: 'Export this note to a text file',
          onPressed: () => _exportOne(entry),
        ),
      ),
    );
  }
}
