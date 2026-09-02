import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/export_service.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import '../services/tts_service.dart';
import '../services/voice_recorder_service.dart';
import '../widgets/knob_dial.dart';
import '../widgets/stereo_panel.dart';

/// Reads real scripture text aloud with on-device text-to-speech - no MP3
/// needed, no waiting on Whisper. The verse being spoken is shown on screen
/// as the caption (word-perfect, since it's the real text, not a guess).
///
/// Hitting the same button that plays/pauses works exactly like the MP3
/// player: pausing playback immediately starts recording a spoken note,
/// tapping again stops it, transcribes it, and saves it - reusing the same
/// VoiceRecorderService + TranscriptService.transcribeVoiceClip flow.
class TtsPlayerScreen extends StatefulWidget {
  final String audioFileId;
  final String sessionId;
  final String sessionLabel;
  final String bookName;
  final String bookId;
  final String translation;
  final int startChapter;
  // If set, jump straight to this verse within startChapter instead of the
  // beginning of the chapter - how "Resume where you left off" picks up
  // exactly where reading stopped last time, not just at the right chapter.
  final int? startVerse;

  const TtsPlayerScreen({
    super.key,
    required this.audioFileId,
    required this.sessionId,
    required this.sessionLabel,
    required this.bookName,
    required this.bookId,
    required this.translation,
    required this.startChapter,
    this.startVerse,
  });

  @override
  State<TtsPlayerScreen> createState() => _TtsPlayerScreenState();
}

class _TtsPlayerScreenState extends State<TtsPlayerScreen> {
  final _storage = SimpleStorage();
  final _bibleText = BibleTextService();
  final _tts = TtsService();
  final _transcripts = TranscriptService();
  final _voiceRecorder = VoiceRecorderService();
  final _export = ExportService();

  final List<BibleVerse> _verses = [];
  int _currentIndex = 0;
  int? _totalChapters;
  bool _reachedEnd = false;
  bool _fetchingMore = false;

  bool _loading = true;
  String? _error;

  bool _isPlaying = false;
  // Bumped every time playback is paused/stopped so an in-flight speak()
  // loop knows to stop advancing instead of racing a newly started one.
  int _playToken = 0;

  // One knob here (not two like the MP3 player) - there's no separate real
  // audio file to desync from, the TTS voice IS what drives the on-screen
  // verse display, so a single rate controls both at once.
  static const List<double> _speechRateSteps = [0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80];
  double _speechRate = 0.45;

  bool _isRecordingNote = false;
  bool _isSavingNote = false;
  int _recordingElapsedSeconds = 0;
  bool _recordingBlinkOn = true;
  Timer? _recordingTimer;
  BibleVerse? _noteVerse;

  // Real phone calls (or other apps grabbing audio focus) are reported by
  // Android the same way our OWN recorder briefly taking the microphone is
  // - _suppressInterruptions tells the two apart so a routine voice note
  // doesn't get mistaken for an incoming call.
  StreamSubscription<AudioInterruptionEvent>? _interruptSub;
  bool _suppressInterruptions = false;

  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    StereoBacklight.ensureLoaded();
    _initInterruptionHandling();
    _init();
  }

  /// Real phone calls (or anything else that needs the audio path) never
  /// got handled on this screen before - only the MP3 player watched for
  /// them. Wires up the same behavior here: pause playback, stop and save
  /// any note in progress, and let the user know.
  Future<void> _initInterruptionHandling() async {
    final session = await AudioSession.instance;
    _interruptSub = session.interruptionEventStream.listen((event) async {
      if (_suppressInterruptions) return; // our own recorder, not a real call
      if (event.begin) {
        final wasPlaying = _isPlaying;
        final wasRecording = _isRecordingNote;
        if (wasPlaying) {
          await _pausePlayback();
        }
        if (wasRecording) {
          await _stopRecordingAndSaveNote();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wasRecording
                    ? 'Paused for phone call - your note was stopped and saved. Tap Play when done.'
                    : 'Paused for phone call – tap Play when done',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      // We don't auto-resume when the interruption ends, same as the MP3
      // player - tap Play when ready.
    });
  }

  Future<void> _init() async {
    try {
      final firstChapter = await _bibleText.fetchChapter(
        widget.bookId,
        widget.startChapter,
        widget.translation,
      );
      if (firstChapter.isEmpty) {
        throw Exception(
          'No verses came back for ${widget.bookName} ${widget.startChapter}.',
        );
      }
      _verses.addAll(firstChapter);
      await _loadNotes();

      // "Resume where you left off" - jump straight to the exact verse
      // instead of the start of the chapter. Falls back to the chapter's
      // first verse if that exact verse number doesn't exist (e.g. a
      // translation with slightly different verse numbering).
      if (widget.startVerse != null) {
        final idx = _verses.indexWhere(
          (v) => v.chapter == widget.startChapter && v.verse == widget.startVerse,
        );
        if (idx >= 0) _currentIndex = idx;
      }

      if (!mounted) return;
      setState(() => _loading = false);

      unawaited(_prefetchRest());

      // Give the screen a moment to actually finish rendering and let you
      // get situated before the voice starts - without this, reading could
      // start while the screen is still settling into place.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      unawaited(_startPlayback());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not load scripture text. Check the tablet\'s internet connection and tap '
              'Try Again.\n\n$e';
        });
      }
    }
  }

  /// Retries after a failed load (e.g. a dropped connection) without
  /// having to back all the way out to the book picker and start over.
  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _loading = true;
      _verses.clear();
      _currentIndex = 0;
      _reachedEnd = false;
    });
    await _init();
  }

  /// Fetches the rest of the book chapter by chapter in the background,
  /// pacing network requests to stay under bible-api.com's rate limit
  /// (bsb's helloao.org backend has no documented limit, so it's paced
  /// lighter) - chapters already cached on disk from a previous read come
  /// back instantly with no delay. Playback simply waits (briefly) if it
  /// ever catches up to what's been fetched.
  ///
  /// Every chapter fetched here gets cached to disk (inside
  /// BibleTextService), so once this finishes once while online, the whole
  /// book keeps working with no internet connection at all - even after
  /// fully closing and reopening the app.
  Future<void> _prefetchRest() async {
    if (_fetchingMore) return;
    _fetchingMore = true;
    try {
      final total = await _bibleText.chapterCount(widget.bookId, widget.translation);
      if (mounted) setState(() => _totalChapters = total);

      final delay = widget.translation == 'bsb'
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 2200);

      for (var chapter = widget.startChapter + 1; chapter <= total; chapter++) {
        final wasCached = await _bibleText.isChapterCached(widget.bookId, chapter, widget.translation);
        final more = await _bibleText.fetchChapter(widget.bookId, chapter, widget.translation);
        if (!mounted) return;
        setState(() => _verses.addAll(more));
        if (chapter < total && !wasCached) {
          await Future.delayed(delay);
        }
      }
      if (mounted) {
        setState(() => _reachedEnd = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.bookName} fully downloaded - available offline now.')),
        );
      }
    } catch (e) {
      // Best effort - if a later chapter fails to fetch (e.g. connection
      // dropped), playback just stops when it catches up to what we
      // already have. Let the user know it's not fully cached yet, rather
      // than failing silently.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not finish downloading the rest of ${widget.bookName} - '
              'check your connection. Already-read chapters are saved for offline use.',
            ),
          ),
        );
      }
    } finally {
      _fetchingMore = false;
    }
  }

  Future<void> _loadNotes() async {
    final notes = await _storage.loadNotes(sessionId: widget.sessionId);
    if (mounted) setState(() => _notes = notes);
  }

  BibleVerse? get _currentVerse =>
      _currentIndex < _verses.length ? _verses[_currentIndex] : (_verses.isEmpty ? null : _verses.last);

  /// Remembers exactly which chapter/verse you're on so "Resume where you
  /// left off" can pick up here next time - even reopened tomorrow as a
  /// brand new Session. Saved on the AudioFile itself (fire-and-forget;
  /// never awaited from the playback loop so it can't stall reading).
  Future<void> _saveReadingProgress() async {
    final verse = _currentVerse;
    if (verse == null) return;
    final all = await _storage.loadAudioFiles();
    final idx = all.indexWhere((f) => f.id == widget.audioFileId);
    if (idx < 0) return;
    if (all[idx].lastChapter == verse.chapter && all[idx].lastVerse == verse.verse) {
      return; // unchanged - skip the write
    }
    all[idx] = all[idx].copyWith(lastChapter: verse.chapter, lastVerse: verse.verse);
    await _storage.saveAudioFiles(all);
  }

  /// Speaks through verses one at a time, starting at _currentIndex.
  /// Stops cleanly (without touching state from a stale run) whenever
  /// _playToken changes out from under it.
  Future<void> _startPlayback() async {
    if (_isPlaying) return;
    final myToken = ++_playToken;
    if (mounted) setState(() => _isPlaying = true);

    while (mounted && myToken == _playToken) {
      if (_currentIndex >= _verses.length) {
        if (_reachedEnd) break; // truly done with the whole book
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      }
      final verse = _verses[_currentIndex];
      setState(() {}); // caption reflects _currentVerse via build()
      unawaited(_saveReadingProgress());
      await _tts.speak(verse.text);
      if (!mounted || myToken != _playToken) return; // paused mid-verse
      setState(() => _currentIndex++);
    }

    if (mounted && myToken == _playToken) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _pausePlayback() async {
    _playToken++; // invalidates any in-flight playback loop
    // Wait for the native stop() to actually finish before doing anything
    // else - starting the recorder (or resuming speech) while it's still
    // in flight is what was causing playback to go silent on resume.
    await _tts.stop();
    if (mounted) setState(() => _isPlaying = false);
    unawaited(_saveReadingProgress());
  }

  // Recorder-style transport, same idea as the MP3 player: Pause stops
  // speech and starts recording a note, Stop ends recording (or just stops
  // playback if nothing's being recorded), Play resumes from where it left
  // off.
  Future<void> _pauseAndRecord() async {
    if (!_isPlaying || _isRecordingNote || _isSavingNote) return;
    _noteVerse = _currentVerse;
    await _pausePlayback();
    await _startRecordingNote();
  }

  Future<void> _stopEverything() async {
    if (_isRecordingNote) {
      await _stopRecordingAndSaveNote();
    } else if (_isPlaying) {
      await _pausePlayback();
    }
  }

  Future<void> _resumePlay() async {
    if (_isPlaying || _isRecordingNote || _isSavingNote) return;
    unawaited(_startPlayback());
  }

  int get _speechRateIndex {
    final idx = _speechRateSteps.indexWhere((s) => (s - _speechRate).abs() < 0.001);
    return idx >= 0 ? idx : _speechRateSteps.indexOf(0.45);
  }

  /// Applies to the NEXT verse, not necessarily the one currently being
  /// read - see TtsService.setSpeechRate.
  Future<void> _setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
    if (mounted) setState(() => _speechRate = rate);
  }

  /// Jumps by a whole verse instead of a number of seconds - TTS mode has
  /// no continuous audio timeline to scrub, just a list of verses spoken
  /// one at a time.
  Future<void> _skipVerses(int delta) async {
    if (_isRecordingNote || _isSavingNote || _verses.isEmpty) return;
    var target = _currentIndex + delta;
    if (target < 0) target = 0;
    if (target > _verses.length - 1) target = _verses.length - 1;
    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      await _pausePlayback();
    }
    if (mounted) setState(() => _currentIndex = target);
    unawaited(_saveReadingProgress());
    if (wasPlaying) {
      unawaited(_startPlayback());
    }
  }

  /// Shown instead of an easy-to-miss SnackBar when the mic permission
  /// check fails - if Android was ever told "Deny" once before, it may
  /// silently refuse to even show the system prompt again, so a direct
  /// path into Settings is the only reliable way back in.
  Future<void> _showMicPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone permission needed'),
        content: const Text(
          'Commute Notes needs microphone access to record voice notes. If '
          'you already tapped "Deny" once, Android may not ask again - turn '
          'it on manually: Settings > Apps > Commute Notes > Permissions > '
          'Microphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecordingNote() async {
    try {
      final hasPermission = await _voiceRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) await _showMicPermissionDialog();
        return;
      }

      final docs = await getApplicationDocumentsDirectory();
      final clipsDir = Directory(p.join(docs.path, 'voice_notes'));
      if (!await clipsDir.exists()) {
        await clipsDir.create(recursive: true);
      }
      final clipPath = p.join(clipsDir.path, '${const Uuid().v4()}.m4a');

      // The recorder taking the microphone/audio focus looks identical to a
      // real phone call to Android - suppress interruption handling while
      // we're the ones causing it. Cleared in _stopRecordingAndSaveNote, or
      // right below if starting fails.
      _suppressInterruptions = true;
      await _voiceRecorder.start(clipPath);

      _recordingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecordingNote = true;
          _recordingElapsedSeconds = 0;
          _recordingBlinkOn = true;
        });
      }
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _recordingElapsedSeconds++;
            _recordingBlinkOn = !_recordingBlinkOn;
          });
        }
      });
    } catch (e) {
      _suppressInterruptions = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSaveNote() async {
    _recordingTimer?.cancel();
    // Focus events from releasing the recorder can lag slightly behind the
    // stop() call itself - stay suppressed a moment longer before treating
    // interruptions as real again.
    Future.delayed(const Duration(milliseconds: 800), () {
      _suppressInterruptions = false;
    });
    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (e) {
      if (mounted) {
        setState(() => _isRecordingNote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop recording: $e')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isRecordingNote = false;
        _isSavingNote = path != null;
      });
    }

    if (path == null) return; // Nothing was actually captured.

    final text = await _transcripts.transcribeVoiceClip(path);
    final verse = _noteVerse;

    final note = Note(
      sessionId: widget.sessionId,
      // No real audio timeline here - use reading position so notes still
      // sort in the order they were taken.
      timestamp: Duration(seconds: _currentIndex),
      captionContext: verse != null ? '${widget.bookName} ${verse.reference}' : widget.bookName,
      text: text,
      voiceClipPath: path,
      isComplete: true,
    );
    await _storage.addNote(note);
    await _loadNotes();

    if (mounted) {
      setState(() => _isSavingNote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note saved')),
      );
    }
  }

  Future<void> _typeNote() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Type a note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What stood out? Any questions?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      final verse = _currentVerse;
      final note = Note(
        sessionId: widget.sessionId,
        timestamp: Duration(seconds: _currentIndex),
        captionContext: verse != null ? '${widget.bookName} ${verse.reference}' : widget.bookName,
        text: text,
        isComplete: true,
      );
      await _storage.addNote(note);
      await _loadNotes();
    }
  }

  Future<void> _showExport() async {
    final title = '${widget.bookName} (${BibleTextService.translations[widget.translation] ?? widget.translation})';
    final plain = _export.toPlainText(
      sessionLabel: widget.sessionLabel,
      audioTitle: title,
      notes: _notes,
    );
    final outline = _export.toOutline(
      sessionLabel: widget.sessionLabel,
      audioTitle: title,
      notes: _notes,
    );

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Text('Notes for ${widget.sessionLabel}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveNotesAsFile(plain),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save as Text File'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: plain));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Notes'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Outline:'),
                  const SizedBox(height: 8),
                  SelectableText(outline),
                  const SizedBox(height: 20),
                  const Text('Plain text:'),
                  const SizedBox(height: 8),
                  SelectableText(plain),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Writes the notes to a small standalone .txt file and hands it to
  /// Android's normal save/share sheet - pick "Save to device" to land it
  /// in Downloads, or share it straight to email/Drive/whatever. Nothing
  /// heavier than plain text - no PDF library, no extra app size.
  Future<void> _saveNotesAsFile(String plain) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _export.safeFileName(widget.sessionLabel);
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsString(plain);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, name: fileName)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save notes file: $e')),
        );
      }
    }
  }

  String _formatElapsed(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  /// A big round icon button with a color and a short label underneath -
  /// used for the whole transport row (Pause/Stop/Play) plus the Type Note
  /// button, so every button in this screen reads the same way: color +
  /// icon + label, easy to tell apart at a glance. [onPressed] null both
  /// disables the button and falls back to normal disabled styling instead
  /// of the custom [background], so a disabled button doesn't look active.
  /// The previous/next VERSE keys - same backlit look as the MP3 player's
  /// REVERSE/FORWARD keys, but they move one whole verse at a time rather
  /// than seeking by seconds (there's no continuous timeline in TTS mode).
  Widget _verseKey(ThemeData theme, {required bool back, required bool enabled}) {
    // Backlight colour, matching the MP3 player's lit keys.
    final color = enabled ? StereoBacklight.color : theme.disabledColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _skipVerses(back ? -1 : 1) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: stereoLitKey(theme, enabled: enabled),
            child: Icon(back ? Icons.fast_rewind : Icons.fast_forward, size: 28, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text('VERSE', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// Round 33: delegates to the shared bevelled key in
  /// widgets/stereo_panel.dart, so this screen's buttons look identical to
  /// the MP3 player's instead of each screen carrying its own copy. Only
  /// the LOOK is shared - this screen keeps its own controls (previous/next
  /// verse rather than 15-second seeks, no caption-nudge module).
  Widget _labeledIconButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color background,
    required Color foreground,
    double size = 84,
    double iconSize = 34,
    Widget? iconOverride,
    IconData? labelIcon,
  }) {
    return stereoKey(
      theme: theme,
      icon: icon,
      label: label,
      onPressed: onPressed,
      background: background,
      foreground: foreground,
      size: size,
      iconSize: iconSize,
      iconOverride: iconOverride,
      labelIcon: labelIcon,
    );
  }

  @override
  void dispose() {
    _playToken++;
    _recordingTimer?.cancel();
    _interruptSub?.cancel();
    _tts.stop();
    _tts.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.sessionLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Fetching ${widget.bookName} ${widget.startChapter}…'),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.sessionLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final verse = _currentVerse;
    final finished = _reachedEnd && _currentIndex >= _verses.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.sessionLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.bookName} • ${BibleTextService.translations[widget.translation] ?? widget.translation}',
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, size: 30),
            tooltip: 'Outline / Export',
            onPressed: _showExport,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        // Round 33 fix: matches the MP3 player - the whole body is wrapped
        // in a scroll view so a tall Column (bigger knob, carbon panels,
        // the straddling PAUSE key) can never silently collapse the
        // flex-based caption box / notes list to zero height in a release
        // build the way it did before this fix.
        child: SingleChildScrollView(
          child: Column(
          children: [
            if (_isRecordingNote)
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      opacity: _recordingBlinkOn ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 400),
                      child: Icon(
                        Icons.fiber_manual_record,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'RECORDING - ${_formatElapsed(_recordingElapsedSeconds)} '
                        '- tap Stop to save it',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isSavingNote)
              Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Transcribing your note…',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (verse != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${widget.bookName} ${verse.reference}'
                    '${_totalChapters != null ? '  •  chapter ${verse.chapter} of $_totalChapters' : ''}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Round 33: matches the MP3 player - a guaranteed minimum height
            // of about two extra lines plus a bigger flex share, so more of
            // the passage shows at once and the controls sit lower.
            Container(
                width: double.infinity,
                height: 260,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.55),
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      finished
                          ? 'You\'ve reached the end of ${widget.bookName}. Great job!'
                          : (verse?.text ?? '…'),
                      style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            // Voice/display speed knob - the only speed control this screen
            // needs, since there's no separate real audio file to desync
            // from (unlike the MP3 player): the TTS voice IS the display.
            // Round 33: same brushed faceplate + knob treatment as the MP3
            // player, and the knob is the same size there too (it was 108
            // here vs 172 there, which made the two screens look like
            // different apps). Still just the ONE knob - there's no caption
            // sync to correct on this screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: CarbonPanel(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BacklightBuilder(
                      builder: (context, glow) => KnobDial(
                        values: _speechRateSteps,
                        selectedIndex: _speechRateIndex,
                        accentColor: glow,
                        labelForTick: (v) => v.toStringAsFixed(2),
                        labelForCenter: (v) =>
                            (v - 0.45).abs() < 0.001 ? 'Normal' : v.toStringAsFixed(2),
                        onChanged: (index) => _setSpeechRate(_speechRateSteps[index]),
                      ),
                    ),
                    Text(
                      'Speed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: (_speechRate - 0.45).abs() > 0.001
                          ? TextButton(
                              onPressed: () => _setSpeechRate(0.45),
                              child: const Text('Reset'),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            // Big primary transport row - Pause, Stop, Play - sized big
            // enough to hit without looking closely, per the "big buttons"
            // ask, with a distinct color + label under each one so they're
            // tellable apart at a glance too, not just by icon shape.
            // Round 33: same faceplate treatment as the MP3 player's
            // transport - identical panel, bevelled keys and sizes. The
            // BUTTONS are unchanged though: this screen still has Stop /
            // Record Note / Play plus previous/next VERSE (there's no
            // continuous timeline here to seek through by seconds), and no
            // caption-nudge module.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Builder(builder: (context) {
                final pauseEnabled = _isPlaying && !_isRecordingNote && !_isSavingNote && !finished;
                final stopEnabled = !_isSavingNote && (_isPlaying || _isRecordingNote);
                final playEnabled = !_isPlaying && !_isRecordingNote && !_isSavingNote && !finished;
                final backEnabled = !(_isRecordingNote || _isSavingNote) && _currentIndex > 0;
                final fwdEnabled = !(_isRecordingNote || _isSavingNote) && _verses.isNotEmpty;
                return CarbonPanel(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _labeledIconButton(
                        theme: theme,
                        icon: Icons.stop,
                        label: 'STOP',
                        onPressed: stopEnabled ? _stopEverything : null,
                        background: Color.lerp(theme.colorScheme.surface, Colors.black, 0.25)!,
                        foreground: theme.colorScheme.onSurface,
                        size: 68,
                        iconSize: 30,
                        iconOverride: _isSavingNote
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: theme.colorScheme.onSurface),
                              )
                            : null,
                      ),
                      _verseKey(theme, back: true, enabled: backEnabled),
                      // Biggest key, centred - pauses AND starts recording a
                      // note in one motion, same as the MP3 player's PAUSE.
                      _labeledIconButton(
                        theme: theme,
                        icon: Icons.pause,
                        label: 'PAUSE',
                        onPressed: pauseEnabled ? _pauseAndRecord : null,
                        background: Color.lerp(theme.colorScheme.surface, Colors.white, 0.16)!,
                        foreground: theme.colorScheme.onSurface,
                        size: 96,
                        iconSize: 42,
                        // Pause bars + outline mic on the cap face, matched
                        // in size - same balanced pair as the MP3 player.
                        iconOverride: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, size: 36, color: theme.colorScheme.onSurface),
                            const SizedBox(width: 5),
                            Icon(Icons.mic_none, size: 36, color: theme.colorScheme.onSurface),
                          ],
                        ),
                      ),
                      _verseKey(theme, back: false, enabled: fwdEnabled),
                      _labeledIconButton(
                        theme: theme,
                        icon: finished ? Icons.check_circle : Icons.play_arrow,
                        label: finished ? 'DONE' : 'PLAY',
                        onPressed: playEnabled ? _resumePlay : null,
                        background: const Color(0xFF19875A),
                        foreground: Colors.white,
                        size: 68,
                        iconSize: 32,
                      ),
                    ],
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _labeledIconButton(
                    theme: theme,
                    icon: Icons.edit_note,
                    label: 'TYPE NOTE',
                    onPressed: _typeNote,
                    background: theme.colorScheme.tertiaryContainer,
                    foreground: theme.colorScheme.onTertiaryContainer,
                    size: 64,
                    iconSize: 28,
                  ),
                  const SizedBox(width: 24),
                  const StereoBacklightSwitch(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _notes.isEmpty
                  ? Center(
                      child: Text(
                        'Notes appear here.\nPause to record one, or tap Type note.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final n = _notes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.colorScheme.tertiaryContainer,
                              child: Icon(
                                Icons.menu_book,
                                size: 22,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            title: Text(
                              n.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(n.captionContext, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        );
                      },
                    ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
