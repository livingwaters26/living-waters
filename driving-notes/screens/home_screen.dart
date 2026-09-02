import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'read_scripture_screen.dart';
import 'record_reading_screen.dart';
import 'todays_notes_screen.dart';
import 'tts_player_screen.dart';

/// One entry in the "Continue your notes" strip - one book/file that you've
/// actually taken notes on, so getting back to something worth exporting
/// after a commute never means digging through folders/files/sessions.
class _ContinueItem {
  final Session session;
  final AudioFile audioFile;
  final String? captionPreview;
  final int noteCount;
  final DateTime activityTime;
  _ContinueItem({
    required this.session,
    required this.audioFile,
    required this.activityTime,
    this.captionPreview,
    this.noteCount = 0,
  });
}

/// The app's actual home screen - three big, high-contrast buttons meant to
/// be readable and tappable at a glance (not read carefully) while
/// driving. Everything else - picking a translation/book, the MP3 list,
/// recording yourself - is exactly one tap away from here.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = SimpleStorage();
  final _transcripts = TranscriptService();
  final _bibleText = BibleTextService();
  List<_ContinueItem> _continueItems = [];
  bool _loadingContinue = true;

  @override
  void initState() {
    super.initState();
    _loadContinueItems();
  }

  Future<void> _loadContinueItems() async {
    setState(() => _loadingContinue = true);
    try {
      final sessions = await _storage.loadSessions();
      final audioFiles = await _storage.loadAudioFiles();
      final notes = await _storage.loadNotes();
      final audioById = {for (final a in audioFiles) a.id: a};
      final sessionById = {for (final s in sessions) s.id: s};

      // Notes don't point at a file directly, only at a session - walk
      // through each note's session to find which file it belongs to, and
      // track both a count and the most recent note time per file.
      final noteCountByFile = <String, int>{};
      final lastNoteByFile = <String, DateTime>{};
      for (final n in notes) {
        final session = sessionById[n.sessionId];
        if (session == null) continue;
        final fileId = session.audioFileId;
        noteCountByFile[fileId] = (noteCountByFile[fileId] ?? 0) + 1;
        final existing = lastNoteByFile[fileId];
        if (existing == null || n.createdAt.isAfter(existing)) {
          lastNoteByFile[fileId] = n.createdAt;
        }
      }

      // One entry per book/file - whichever session on that file was
      // touched most recently - so several active studies each show up
      // once, not buried under every session you've ever started.
      final mostRecentByFile = <String, Session>{};
      for (final s in sessions) {
        if (!audioById.containsKey(s.audioFileId)) continue; // orphaned - shouldn't normally happen
        final existing = mostRecentByFile[s.audioFileId];
        if (existing == null || s.updatedAt.isAfter(existing.updatedAt)) {
          mostRecentByFile[s.audioFileId] = s;
        }
      }

      // Only files you've actually taken notes on - the point of this list
      // is getting straight back to notes worth reviewing/exporting after a
      // commute, not everything you've ever pressed play on. Ranked by the
      // date of the most recent note itself, newest first.
      final candidates = mostRecentByFile.values
          .where((s) => (noteCountByFile[s.audioFileId] ?? 0) > 0)
          .map((s) => (session: s, activityTime: lastNoteByFile[s.audioFileId]!))
          .toList()
        ..sort((a, b) => b.activityTime.compareTo(a.activityTime));
      final top = candidates.take(10).toList();

      final items = <_ContinueItem>[];
      for (final c in top) {
        final audioFile = audioById[c.session.audioFileId]!;
        String? preview;
        try {
          final segs = await _transcripts.load(c.session.audioFileId);
          if (segs != null) {
            preview = _transcripts.segmentAt(segs, c.session.lastPosition)?.text;
          }
        } catch (_) {
          // Missing/corrupt transcript shouldn't block showing the entry itself.
        }
        items.add(_ContinueItem(
          session: c.session,
          audioFile: audioFile,
          captionPreview: preview,
          noteCount: noteCountByFile[c.session.audioFileId] ?? 0,
          activityTime: c.activityTime,
        ));
      }

      if (mounted) {
        setState(() {
          _continueItems = items;
          _loadingContinue = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContinue = false);
    }
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(day).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return '$diffDays days ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _openContinueItem(_ContinueItem item) {
    // Read Scripture (TTS) sessions live on a synthetic path
    // 'tts:<translation>:<bookId>', not a real MP3 - route those into the
    // TTS player instead, resuming at whatever chapter/verse the book
    // itself last saved (see AudioFile.lastChapter/lastVerse).
    final parts = item.audioFile.path.split(':');
    final isTts = parts.length == 3 && parts[0] == 'tts';

    if (isTts) {
      final translation = parts[1];
      final bookId = parts[2];
      final bookName = _bibleText.bookNameForId(bookId) ?? item.audioFile.title;
      final startChapter = item.audioFile.lastChapter > 0 ? item.audioFile.lastChapter : 1;
      final startVerse = item.audioFile.lastVerse > 0 ? item.audioFile.lastVerse : null;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => TtsPlayerScreen(
                audioFileId: item.audioFile.id,
                sessionId: item.session.id,
                sessionLabel: item.session.label,
                bookName: bookName,
                bookId: bookId,
                translation: translation,
                startChapter: startChapter,
                startVerse: startVerse,
              ),
            ),
          )
          .then((_) => _loadContinueItems());
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              audioFileId: item.audioFile.id,
              sessionId: item.session.id,
              sessionLabel: item.session.label,
              audioTitle: item.audioFile.title,
            ),
          ),
        )
        .then((_) => _loadContinueItems());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Driving Notes')),
      // Small and floating, deliberately not a fourth big button - the
      // three-button layout is the whole point of this screen. This is
      // just a way in to every note you've taken, from every book/file, in
      // one place, so it sits low-key at the bottom instead of competing
      // with the primary actions.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'todaysNotes',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TodaysNotesScreen()),
        ),
        icon: const Icon(Icons.event_note),
        label: const Text("Today's Notes"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              // Straight back to notes worth reviewing/exporting - only
              // studies you've actually taken notes in, newest note first,
              // so you're never digging through folders/files/sessions
              // just to find what to export when you get home. Only takes
              // up room when there's something to show.
              if (!_loadingContinue && _continueItems.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Continue your notes',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _continueItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = _continueItems[index];
                      return _ContinueCard(
                        item: item,
                        relativeTime: _relativeTime(item.activityTime),
                        onTap: () => _openContinueItem(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _HomeButton(
                        label: 'Read Scripture',
                        icon: Icons.menu_book,
                        color: const Color(0xFF1F6FB2),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const ReadScriptureScreen()))
                            .then((_) => _loadContinueItems()),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _HomeButton(
                        label: 'My MP3s',
                        icon: Icons.library_music,
                        color: const Color(0xFF19875A),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const LibraryScreen()))
                            .then((_) => _loadContinueItems()),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _HomeButton(
                        label: 'Record a Reading',
                        icon: Icons.mic,
                        color: const Color(0xFFCB6A1E),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const RecordReadingScreen()))
                            .then((_) => _loadContinueItems()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact card for one "continue where you left off" entry - deliberately
/// smaller/quieter than the three main buttons (this is a "pick before you
/// pull out of the driveway" glance, not a while-driving tap target).
class _ContinueCard extends StatelessWidget {
  final _ContinueItem item;
  final String relativeTime;
  final VoidCallback onTap;

  const _ContinueCard({required this.item, required this.relativeTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.audioFile.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (item.captionPreview != null && item.captionPreview!.trim().isNotEmpty)
                Text(
                  '"${item.captionPreview!.trim()}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.noteCount > 0) ...[
                    Icon(Icons.sticky_note_2_outlined, size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${item.noteCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One big full-width, full-height-share, brightly colored tap target.
/// Deliberately simple - one icon, one short word or two, nothing else to
/// read or misread while glancing at the screen.
class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 76, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
