import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import 'player_screen.dart';

/// Shows all labeled Sessions for one AudioFile + ability to create a new one.
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
  List<TranscriptSegment> _segments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _storage.loadSessions(audioFileId: widget.audioFileId);
    // Captions belong to the audio file itself, not to any one session, so
    // every session for this file shares the same transcript - used below
    // to show what was actually being said at each session's last position.
    final segs = await _transcripts.load(widget.audioFileId);
    if (mounted) {
      setState(() {
        _sessions = list;
        _segments = segs ?? [];
        _loading = false;
      });
    }
  }

  /// New sessions are named after the MP3 itself plus the date AND time -
  /// so two sessions started the same day (e.g. two sittings with the same
  /// book) still get distinct names instead of both saying just "8/18/2026".
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

  String _formatPosition(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
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
                : _sessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No sessions yet.\nCreate one to start listening & taking notes.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final s = _sessions[index];
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
                              trailing: Icon(
                                Icons.play_circle_fill,
                                size: 44,
                                color: Theme.of(context).colorScheme.primary,
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
