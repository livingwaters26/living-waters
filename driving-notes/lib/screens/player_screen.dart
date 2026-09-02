import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../services/audio_player_service.dart';
import '../services/bible_text_service.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/simple_storage.dart';
import '../services/transcript_service.dart';
import '../services/voice_recorder_service.dart';
import '../widgets/knob_dial.dart';
import '../widgets/stereo_panel.dart';
import 'read_scripture_screen.dart';

/// Main commute / spa screen. Hitting pause starts recording a spoken note;
/// hitting the same button again stops it, transcribes it, and saves it.
class PlayerScreen extends ConsumerStatefulWidget {
  final String audioFileId;
  final String sessionId;
  final String sessionLabel;
  final String audioTitle;

  const PlayerScreen({
    super.key,
    required this.audioFileId,
    required this.sessionId,
    required this.sessionLabel,
    required this.audioTitle,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _storage = SimpleStorage();
  final _audio = AudioPlayerService();
  final _transcripts = TranscriptService();
  final _export = ExportService();
  final _voiceRecorder = VoiceRecorderService();
  final _bibleText = BibleTextService();
  final _settings = SettingsService();
  String _captionTranslation = 'bsb';

  bool _loading = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _generatingCaptions = false;
  int _captionProgress = 0;
  int _captionElapsedSeconds = 0;
  Timer? _captionTimer;

  bool _isRecordingNote = false;
  bool _isSavingNote = false;
  int _recordingElapsedSeconds = 0;
  bool _recordingBlinkOn = true;
  Timer? _recordingTimer;
  Duration _noteTimestamp = Duration.zero;
  String _noteCaptionContext = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _currentCaption = 'Loading…';
  String? _error;

  // Playback speed - finer steps clustered around normal (0.75-0.95, for
  // slowing down a fast reading a little at a time) and coarser ones above
  // and below for the extremes.
  static const List<double> _speedSteps = [0.5, 0.6, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.0, 1.25, 1.5, 2.0];
  double _speed = 1.0;

  // Only used when the loaded transcript is estimated (scripture-synced
  // captions, not real Whisper timestamps) - lets the estimate be nudged
  // back into sync with the actual narration without regenerating anything.
  // A flat millisecond shift (not a multiplier) - see AudioFile.captionSyncOffsetMs.
  int _captionSyncOffsetMs = 0;
  Timer? _syncSaveTimer;

  AudioFile? _audioFile;
  Session? _session;
  List<Note> _notes = [];
  List<TranscriptSegment> _segments = [];
  // Both possible caption sets, kept in memory so switching the toggle (or
  // regenerating one kind) doesn't need a disk round-trip.
  TranscriptBundle _bundle = const TranscriptBundle();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription<bool>? _interruptSub;

  @override
  void initState() {
    super.initState();
    _settings.getCaptionTranslation().then((id) {
      if (mounted) setState(() => _captionTranslation = id);
    });
    StereoBacklight.ensureLoaded();
    _init();
  }

  Future<void> _init() async {
    try {
      await _audio.init();

      final files = await _storage.loadAudioFiles();
      _audioFile = files.cast<AudioFile?>().firstWhere(
            (f) => f?.id == widget.audioFileId,
            orElse: () => null,
          );

      final sessions = await _storage.loadSessions(audioFileId: widget.audioFileId);
      _session = sessions.cast<Session?>().firstWhere(
            (s) => s?.id == widget.sessionId,
            orElse: () => null,
          );

      if (_audioFile == null) {
        setState(() {
          _loading = false;
          _error = 'Audio file not found in library.';
        });
        return;
      }

      if (!await File(_audioFile!.path).exists()) {
        // Older imports (before round 6) stored a path into the file
        // picker's TEMPORARY cache instead of copying into the app's own
        // storage - Android can clear that cache at any time, which is
        // exactly what this means. Newly-imported files don't have this
        // problem anymore.
        setState(() {
          _loading = false;
          _error =
              'The audio file for this session can\'t be found anymore - it may have been a '
              'temporary copy that Android cleaned up. Go back to My MP3s, delete this entry, '
              'and import the file again.';
        });
        return;
      }

      final dur = await _audio.setFile(_audioFile!.path);
      if (dur != null) {
        _duration = dur;
        if (_audioFile!.duration == Duration.zero) {
          final updated = _audioFile!.copyWith(duration: dur);
          final all = await _storage.loadAudioFiles();
          final idx = all.indexWhere((f) => f.id == updated.id);
          if (idx >= 0) {
            all[idx] = updated;
            await _storage.saveAudioFiles(all);
          }
          _audioFile = updated;
        }
      }
      _captionSyncOffsetMs = _audioFile?.captionSyncOffsetMs ?? 0;

      _bundle = await _transcripts.loadBundle(widget.audioFileId);
      var segs = _segmentsForKind(_audioFile!.activeCaptionKind);
      if (segs == null || segs.isEmpty) {
        if (_bundle.whisper == null && _bundle.scripture == null) {
          // Nothing generated yet at all - seed a placeholder in the
          // 'whisper' slot, same as always.
          segs = await _transcripts.createPlaceholder(
            audioFileId: widget.audioFileId,
            duration: _duration > Duration.zero ? _duration : const Duration(minutes: 10),
          );
          _bundle = TranscriptBundle(whisper: segs, scripture: _bundle.scripture);
        } else {
          // The saved "active" kind is empty but the other kind has real
          // captions - fall back to whichever exists rather than showing
          // nothing.
          segs = _bundle.whisper ?? _bundle.scripture ?? [];
        }
      }
      _segments = segs;
      _updateCaption(_position);

      if (_session != null && _session!.lastPosition > Duration.zero) {
        await _audio.seek(_session!.lastPosition);
        _position = _session!.lastPosition;
        _updateCaption(_position);
      }

      _posSub = _audio.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
            _updateCaption(pos);
          });
        }
      });
      _durSub = _audio.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
      _stateSub = _audio.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      });

      _interruptSub = _audio.interruptionStream.listen((interrupted) async {
        if (interrupted) {
          await _savePosition();
          // A real interruption (recorder-triggered ones are suppressed -
          // see AudioPlayerService.setSuppressInterruptions) while a note
          // was being recorded is most likely an actual incoming call.
          // Stop and save whatever was captured instead of leaving the
          // recorder running through the call.
          final wasRecording = _isRecordingNote;
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
      });

      await _loadNotes();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load audio: $e';
        });
      }
    }
  }

  /// For estimated (scripture-synced) captions only - shifts real playback
  /// position by a flat number of seconds before looking up which caption
  /// to show, so the sync adjustment control can pull a drifting estimate
  /// back in line without touching the actual saved segment timings or
  /// regenerating anything. A plain offset (not a multiplier) so "+10s"
  /// always means exactly 10 seconds, everywhere in the file.
  Duration _captionLookupPosition(Duration pos) {
    if (_audioFile?.activeCaptionKind != 'scripture' || _captionSyncOffsetMs == 0) {
      return pos;
    }
    final shiftedMs = pos.inMilliseconds + _captionSyncOffsetMs;
    return Duration(milliseconds: shiftedMs < 0 ? 0 : shiftedMs);
  }

  void _updateCaption(Duration pos) {
    final seg = _transcripts.segmentAt(_segments, _captionLookupPosition(pos));
    _currentCaption = seg?.text ?? '…';
  }

  List<TranscriptSegment>? _segmentsForKind(String kind) =>
      kind == 'scripture' ? _bundle.scripture : _bundle.whisper;

  /// Switches which saved caption set is showing - only relevant once both
  /// a Whisper transcript and scripture-synced captions exist for this
  /// file. Persists the choice so it's remembered next time this file is
  /// opened.
  Future<void> _switchCaptionKind(String kind) async {
    if (_audioFile == null || _audioFile!.activeCaptionKind == kind) return;
    final segs = _segmentsForKind(kind) ?? [];
    final updated = _audioFile!.copyWith(activeCaptionKind: kind);
    final all = await _storage.loadAudioFiles();
    final idx = all.indexWhere((f) => f.id == updated.id);
    if (idx >= 0) {
      all[idx] = updated;
      await _storage.saveAudioFiles(all);
    }
    if (!mounted) return;
    setState(() {
      _audioFile = updated;
      _segments = segs;
      _captionSyncOffsetMs = updated.captionSyncOffsetMs;
      _updateCaption(_position);
    });
  }

  Future<void> _loadNotes() async {
    final notes = await _storage.loadNotes(sessionId: widget.sessionId);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _savePosition() async {
    if (_session == null) return;
    final updated = _session!.copyWith(lastPosition: _position);
    await _storage.updateSession(updated);
    _session = updated;
  }

  /// Three separate transport controls, like a standard recorder: Pause
  /// (stops playback and immediately starts recording a spoken note,
  /// capturing the timestamp + caption you were just hearing), Stop (ends
  /// recording if one's in progress - transcribing and saving it as a Note
  /// - and makes sure playback is stopped too), and Play (resumes/starts
  /// playback from a fully idle state).
  Future<void> _pauseAndRecord() async {
    if (!_isPlaying || _isRecordingNote || _isSavingNote) return;
    await _audio.pause();
    await _savePosition();
    await _startRecordingNote();
  }

  Future<void> _stopEverything() async {
    if (_isRecordingNote) {
      await _stopRecordingAndSaveNote();
    } else if (_isPlaying) {
      await _audio.pause();
      await _savePosition();
    }
  }

  Future<void> _resumePlay() async {
    if (_isPlaying || _isRecordingNote || _isSavingNote) return;
    await _audio.play();
  }

  /// Seeks to [target] (clamped to the start/end of the file) and updates
  /// the on-screen position/caption, WITHOUT saving it to the session yet.
  /// Split out from _skip so continuous press-and-hold seeking (see
  /// _startContinuousSeek) can call this every tick without hammering
  /// storage - it saves once, when the hold ends, instead.
  Future<Duration> _seekTo(Duration target) async {
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (_duration > Duration.zero && clamped > _duration) clamped = _duration;
    await _audio.seek(clamped);
    if (mounted) {
      setState(() {
        _position = clamped;
        _updateCaption(clamped);
      });
    }
    return clamped;
  }

  /// Jumps the current position back/forward by [delta] (use a negative
  /// Duration to go back), clamped to the start/end of the file, and saves
  /// the new position right away - this is the normal single-tap behavior.
  Future<void> _skip(Duration delta) async {
    if (_isRecordingNote || _isSavingNote) return;
    await _seekTo(_position + delta);
    await _savePosition();
  }

  Timer? _continuousSeekTimer;
  static const _continuousSeekStepSeconds = 2;
  static const _continuousSeekInterval = Duration(milliseconds: 150);

  /// Starts continuously seeking (and, since _seekTo updates the caption
  /// every tick, continuously scrolling the caption text along with it) in
  /// [direction] (-1 back, +1 forward) for as long as the rewind/
  /// fast-forward button is held down - like the fast-forward/rewind on a
  /// real recorder, not just a fixed jump. Fires once immediately so
  /// holding feels responsive instead of waiting for the first tick.
  void _startContinuousSeek(int direction) {
    if (_isRecordingNote || _isSavingNote) return;
    _continuousSeekTimer?.cancel();
    final delta = Duration(seconds: _continuousSeekStepSeconds * direction);
    _seekTo(_position + delta);
    _continuousSeekTimer = Timer.periodic(_continuousSeekInterval, (_) {
      _seekTo(_position + delta);
    });
  }

  /// Stops a press-and-hold seek in progress and saves the final position
  /// ONE time - not on every ~150ms tick while it was held, which would
  /// otherwise spam the session file with writes for no benefit.
  Future<void> _stopContinuousSeek() async {
    if (_continuousSeekTimer == null) return;
    _continuousSeekTimer?.cancel();
    _continuousSeekTimer = null;
    await _savePosition();
  }

  /// Shared building block for every rewind/fast-forward control on this
  /// screen - the dial card's outer `<`/`>` chevrons AND the transport
  /// card's rewind/forward buttons. A single tap always does the normal
  /// fixed [seconds] jump. [holdToScrub] additionally wires press-and-hold
  /// to continuous seeking (see _startContinuousSeek) - only the transport
  /// card's arrows do this; the dial card's edge chevrons are plain tap-only
  /// (that continuous-scroll behavior isn't part of what those represent).
  /// [label] is optional trailing text (e.g. "15s"); pass null for an
  /// icon-only control. [bordered] draws a rounded outline like the app's
  /// other outlined buttons; the dial card's chevrons skip that since they
  /// sit flush inside the shared card background instead.
  Widget _seekControl({
    required IconData icon,
    required int seconds,
    required bool enabled,
    String? label,
    String? caption,
    double iconSize = 28,
    bool bordered = false,
    bool holdToScrub = true,
  }) {
    final theme = Theme.of(context);
    final direction = seconds.sign;
    // Backlight colour, not the theme's primary - these are lit keys, so
    // their glyphs track the deck's backlight like their borders do.
    final color = enabled ? StereoBacklight.color : theme.disabledColor;
    final canHold = enabled && holdToScrub;
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _skip(Duration(seconds: seconds)) : null,
      onLongPressStart: canHold ? (_) => _startContinuousSeek(direction) : null,
      onLongPressEnd: canHold ? (_) => _stopContinuousSeek() : null,
      onLongPressCancel: canHold ? _stopContinuousSeek : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: bordered ? 18 : 10, vertical: bordered ? 16 : 8),
        // A bordered seek button is a dark BACKLIT key mounted on the brushed
        // panel (see _panelDecoration): filled rather than merely outlined
        // (an outline alone reads as a hole cut in the faceplate), with a
        // glowing edge and a soft outer bloom in the accent color, like the
        // illuminated transport keys on a real deck.
        decoration: bordered
            ? BoxDecoration(
                color: Color.lerp(theme.colorScheme.surface, Colors.black, 0.35)!,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enabled
                      ? theme.colorScheme.primary.withOpacity(0.85)
                      : theme.colorScheme.onSurface.withOpacity(0.12),
                  width: enabled ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 5, offset: const Offset(0, 2)),
                  if (enabled)
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                ],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 16, color: color)),
            ],
          ],
        ),
      ),
    );
    if (caption == null) return button;
    // Caption underneath, matching the labels under the round transport
    // buttons either side of these, so the whole row reads as one set.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 4),
        Text(caption, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
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
          'Driving Notes needs microphone access to record voice notes. If '
          'you already tapped "Deny" once, Android may not ask again - turn '
          'it on manually: Settings > Apps > Driving Notes > Permissions > '
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

      // Capture what was on screen the moment we paused - not whatever it
      // drifts to while recording.
      _noteTimestamp = _position;
      _noteCaptionContext = _currentCaption;

      // The recorder taking the microphone/audio focus looks identical to a
      // real phone call to Android - suppress interruption handling while
      // we're the ones causing it. Cleared in _stopRecordingAndSaveNote, or
      // right below if starting fails.
      _audio.setSuppressInterruptions(true);
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
      _audio.setSuppressInterruptions(false);
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
      _audio.setSuppressInterruptions(false);
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

    final note = Note(
      sessionId: widget.sessionId,
      timestamp: _noteTimestamp,
      captionContext: _noteCaptionContext,
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

  Future<void> _toggleMute() async {
    await _audio.toggleMute();
    setState(() => _isMuted = _audio.isMuted);
  }

  int get _speedIndex {
    final idx = _speedSteps.indexWhere((s) => (s - _speed).abs() < 0.001);
    return idx >= 0 ? idx : _speedSteps.indexOf(1.0);
  }

  Future<void> _setSpeed(double speed) async {
    await _audio.setSpeed(speed);
    if (mounted) setState(() => _speed = speed);
  }

  Future<void> _nudgeCaptionSyncSeconds(int seconds) async {
    await _setCaptionSyncOffsetMs(_captionSyncOffsetMs + seconds * 1000);
  }

  /// Sets the estimated-caption sync offset directly (not a delta) and
  /// saves it on the AudioFile so the correction sticks the next time this
  /// file is opened, not just for this sitting. A flat number of
  /// milliseconds, not a multiplier - see AudioFile.captionSyncOffsetMs.
  Future<void> _setCaptionSyncOffsetMs(int ms) async {
    if (_audioFile == null) return;
    // int.clamp(int,int) returns num, not int - .toInt() avoids an assignment
    // type error (a recurring Dart gotcha in this codebase).
    final next = ms.clamp(-120000, 120000).toInt();
    setState(() {
      _captionSyncOffsetMs = next;
      _updateCaption(_position);
    });
    final updated = _audioFile!.copyWith(captionSyncOffsetMs: next);
    _audioFile = updated;
    _syncSaveTimer?.cancel();
    _syncSaveTimer = Timer(const Duration(milliseconds: 450), () async {
      final all = await _storage.loadAudioFiles();
      final idx = all.indexWhere((f) => f.id == updated.id);
      if (idx >= 0) {
        all[idx] = updated;
        await _storage.saveAudioFiles(all);
      }
    });
  }

  /// Round 33: Speed and (when shown) Nudge Captions now share ONE card
  /// with a divider between them, instead of two separate side-by-side
  /// cards with a gap (round 32) - matches the layout the user settled on
  /// after a design pass with an AI mockup tool. Small `<`/`>` chevrons sit
  /// on the card's outer edges - plain tap-to-skip-15s, not press-and-hold
  /// (see _seekControl's holdToScrub param - that continuous-scroll
  /// behavior lives on the transport card's arrow buttons instead, not
  /// here, per the user's explicit call).
  /// The brushed-metal panel look shared by the dial card and the transport
  /// card. Round 33 (third pass): these cards used to be a nearly-black
  /// translucent fill, which is what kept the screen reading as "flat dark
  /// app UI" no matter how good the knob itself got. A real stereo's face
  /// plate is a LIGHTER brushed panel that the black controls sit on top of
  /// - so this is a light-to-dark vertical gradient (the "brushed" sheen)
  /// with a lit top edge and a drop shadow, and the buttons/insets on top
  /// of it are the dark elements.
  /// Both of these now live in widgets/stereo_panel.dart so the MP3 player
  /// and the TTS player share one definition instead of drifting apart -
  /// these stay as thin local aliases just so existing call sites read the
  /// same as before.
  BoxDecoration _panelDecoration(ThemeData theme) => stereoPanel(theme);

  BoxDecoration _insetDecoration(ThemeData theme) => stereoInset(theme);

  Widget _dialCard(ThemeData theme) {
    final scrubEnabled = !(_isRecordingNote || _isSavingNote);
    final showNudge = (_audioFile?.activeCaptionKind == 'scripture') ||
        (_audioFile?.hasScriptureCaptions ?? false);
    return CarbonPanel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _speedDialContent(theme)),
            if (showNudge) ...[
              const SizedBox(width: 8),
              // Wrapped so the module repaints when the backlight changes -
              // its chevrons and "On time" are lit in that colour.
              Expanded(
                child: BacklightBuilder(
                  builder: (context, glow) => _captionSyncModule(theme, scrubEnabled),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One `<`/`>` key flanking the Screen Nudge well - a tall backlit strip.
  /// Round 33 (fifth pass): these used to reuse the module's own inset
  /// decoration, which meant they were the exact same dark as the box behind
  /// them and all but disappeared. They're keys, so they get the same lit
  /// treatment as REVERSE/FORWARD on the transport card.
  Widget _dialEdgeChevron({required IconData icon, required int seconds, required bool enabled}) {
    final theme = Theme.of(context);
    return Container(
      width: 38,
      decoration: stereoLitKey(theme, enabled: enabled),
      child: Center(
        child: _seekControl(
          icon: icon,
          seconds: seconds,
          enabled: enabled,
          iconSize: 24,
          holdToScrub: false,
        ),
      ),
    );
  }

  /// Label + knob + Reset slot for the Speed dial - split out from
  /// _dialCard just so that method reads cleanly.
  Widget _speedDialContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BacklightBuilder(
          builder: (context, glow) => KnobDial(
            values: _speedSteps,
            selectedIndex: _speedIndex,
            accentColor: glow,
            labelForTick: (v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}x',
            labelForCenter: (v) => '${v.toStringAsFixed(2)}x',
            onChanged: (index) => _setSpeed(_speedSteps[index]),
          ),
        ),
        // Round 33: "Speed" sits UNDER the knob (it used to be a label +
        // speedometer icon above it) - on a real stereo the legend is
        // printed on the panel below the knob, and that's what the
        // reference design does too.
        Text(
          'Speed',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
        // Fixed-height slot whether or not Reset is showing, so the panel
        // doesn't change height depending on the value.
        SizedBox(
          height: 32,
          child: (_speed - 1.0).abs() > 0.001
              ? TextButton(
                  onPressed: () => _setSpeed(1.0),
                  child: const Text('Reset'),
                )
              : null,
        ),
      ],
    );
  }

  /// Round 33 (fourth pass): the caption-sync controls are their own MODULE
  /// on the faceplate - a dark outer box carrying the "Nudge captions"
  /// legend and the big current reading, and inside it a row of
  /// [`<` key][recessed button box][`>` key]. Previously the chevrons sat
  /// outside this box entirely, so it read as one flat inset rather than a
  /// separate component slotted into the stereo.
  Widget _captionSyncModule(ThemeData theme, bool scrubEnabled) {
    // Just a fixed legend for the module now - the live +/-Ns reading that
    // used to sit here was noise; what the buttons do is self-evident, and
    // the "On time" reset below already says when nothing's applied.
    const label = 'Screen Nudge';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      decoration: _insetDecoration(theme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dialEdgeChevron(icon: Icons.chevron_left, seconds: -15, enabled: scrubEnabled),
                const SizedBox(width: 6),
                Expanded(child: _captionSyncNudgePad(theme)),
                const SizedBox(width: 6),
                _dialEdgeChevron(icon: Icons.chevron_right, seconds: 15, enabled: scrubEnabled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The button well inside the caption-sync module - the Earlier/Later grid
  /// plus the "On time" reset.
  ///
  /// Round 33 (fifth pass): this was the one area still reading as stock
  /// Material UI while everything around it had become hardware. Three
  /// things were wrong: the well was filled LIGHTER than the module around
  /// it, so it sat there as a pale grey slab on an otherwise dark carbon
  /// deck; the keys were plain rounded rectangles rather than the stadium
  /// pills the reference uses; and nothing in here picked up the backlight,
  /// so it stayed grey while the rest of the deck glowed. Now: a genuinely
  /// recessed (darker, black-rimmed) well, stadium keys with the same
  /// top-lit bevel as every other key on the deck, and the reset lit in the
  /// backlight colour.
  Widget _captionSyncNudgePad(ThemeData theme) {
    final seconds = (_captionSyncOffsetMs / 1000).round();
    final glow = StereoBacklight.color;
    // Slate-tinted rather than neutral grey - picks up a hint of the deck's
    // cool cast instead of reading as flat Material surface colour.
    final capBase = Color.lerp(theme.colorScheme.surfaceContainerHighest, const Color(0xFF44506A), 0.35)!;

    Widget bigBtn(String text, int delta) {
      return SizedBox(
        width: 70,
        height: 46,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(capBase, Colors.white, 0.22)!,
                capBase,
                Color.lerp(capBase, Colors.black, 0.34)!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(23),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _nudgeCaptionSyncSeconds(delta),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget columnLabel(String text) => Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.65),
            fontWeight: FontWeight.w600,
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        // Recessed: DARKER than the module around it, with a black rim, so
        // the keys sit down in a well instead of on a raised pale slab.
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  columnLabel('Earlier'),
                  const SizedBox(height: 6),
                  bigBtn('10', -10),
                  const SizedBox(height: 8),
                  bigBtn('1', -1),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  columnLabel('Later'),
                  const SizedBox(height: 6),
                  bigBtn('10', 10),
                  const SizedBox(height: 8),
                  bigBtn('1', 1),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: seconds == 0 ? null : () => _setCaptionSyncOffsetMs(0),
            style: TextButton.styleFrom(
              foregroundColor: glow,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('On time', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Round 33 (second pass): one transport card holding all five controls
  /// in a single row - STOP / REVERSE / PAUSE / FORWARD / PLAY - matching
  /// the reference design. Play and Pause are SEPARATE buttons again (not
  /// a merged toggle), and PAUSE keeps its long-standing behavior of
  /// pausing AND starting a voice note - which is why it carries a mic
  /// glyph next to the pause bars, so what it actually does is visible on
  /// the button itself. That also means there's no longer a separate
  /// "Record Note" button below; PAUSE is it.
  Widget _transportCard(ThemeData theme) {
    final pauseEnabled = _isPlaying && !_isRecordingNote && !_isSavingNote;
    final playEnabled = !_isPlaying && !_isRecordingNote && !_isSavingNote;
    final stopEnabled = !_isSavingNote && (_isPlaying || _isRecordingNote);
    final scrubEnabled = !(_isRecordingNote || _isSavingNote);
    final buttonFace = Color.lerp(theme.colorScheme.surface, Colors.black, 0.25)!;
    // Round 33 (fourth pass): STOP+REVERSE and FORWARD+PLAY are two SEPARATE
    // faceplate modules with a gap between them, and the big PAUSE key
    // straddles that gap - sitting proud on top of both, breaking their
    // outline, exactly like the oversized transport button on a real deck.
    // Previously all five sat inside one flat card.
    // Fixed height: this Stack+stretch Row used to sit in a
    // SingleChildScrollView (unbounded height). Stretch then asked for
    // infinite height, the transport laid out to 0/failed in release, and
    // everything AFTER it (mute, type note, notes list) never painted.
    return SizedBox(
      height: 128,
      child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CarbonPanel(
                padding: const EdgeInsets.fromLTRB(10, 14, 44, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _labeledIconButton(
                      theme: theme,
                      icon: Icons.stop,
                      label: 'STOP',
                      onPressed: stopEnabled ? _stopEverything : null,
                      background: buttonFace,
                      foreground: theme.colorScheme.onSurface,
                      size: 68,
                      iconSize: 30,
                      iconOverride: _isSavingNote
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.onSurface),
                            )
                          : null,
                    ),
                    _seekControl(
                      icon: Icons.fast_rewind,
                      seconds: -15,
                      enabled: scrubEnabled,
                      iconSize: 28,
                      bordered: true,
                      caption: 'REVERSE',
                    ),
                  ],
                ),
              ),
            ),
            // The gap the PAUSE key straddles - with backlight spilling out
            // of the seam between the two modules.
            const StereoSeamGlow(width: 26),
            Expanded(
              child: CarbonPanel(
                padding: const EdgeInsets.fromLTRB(44, 14, 10, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _seekControl(
                      icon: Icons.fast_forward,
                      seconds: 15,
                      enabled: scrubEnabled,
                      iconSize: 28,
                      bordered: true,
                      caption: 'FORWARD',
                    ),
                    _labeledIconButton(
                      theme: theme,
                      icon: Icons.play_arrow,
                      label: 'PLAY',
                      onPressed: playEnabled ? _resumePlay : null,
                      background: const Color(0xFF19875A),
                      foreground: Colors.white,
                      size: 68,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // The oversized centre key, proud of both modules. Pauses playback
        // AND starts recording a spoken note in one motion (unchanged
        // behavior) - the mic glyph beside the pause bars says so.
        _labeledIconButton(
          theme: theme,
          icon: Icons.pause,
          label: 'PAUSE',
          onPressed: pauseEnabled ? _pauseAndRecord : null,
          background: Color.lerp(theme.colorScheme.surface, Colors.white, 0.16)!,
          foreground: theme.colorScheme.onSurface,
          size: 100,
          iconSize: 44,
          // Pause bars AND a mic, both on the cap face - the mic belongs
          // here, not tucked beside the label: this key is the one that
          // starts a voice note, and the glyph pair is what makes that
          // obvious at a glance on a big centre button. The two glyphs are
          // matched in size and the mic is the OUTLINE style (mic_none), so
          // the pair reads as one balanced mark rather than a big filled
          // pause with a smaller solid blob stuck next to it.
          iconOverride: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause, size: 38, color: theme.colorScheme.onSurface),
              const SizedBox(width: 5),
              Icon(Icons.mic_none, size: 38, color: theme.colorScheme.onSurface),
            ],
          ),
        ),
      ],
    ),
    );
  }


  String _formatOffsetSeconds(double seconds) {
    final rounded = seconds.round();
    if (rounded == 0) return 'In sync';
    return rounded > 0 ? '+${rounded}s' : '${rounded}s';
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
      final note = Note(
        sessionId: widget.sessionId,
        timestamp: _position,
        captionContext: _currentCaption,
        text: text,
        isComplete: true,
      );
      await _storage.addNote(note);
      await _loadNotes();
    }
  }

  /// Second confirmation, shown ONLY after picking "Transcribe Anyway" -
  /// round 31: the length/can't-cancel/Wi-Fi warning used to show to
  /// EVERYONE who opened the main dialog, even though it has nothing to do
  /// with the other two (instant) options. Moved here so the main dialog
  /// stays short and this only appears for the one path it actually
  /// applies to. Returns true to actually proceed with Whisper.
  Future<bool> _confirmWhisperTiming() async {
    final estMinutes = _duration > Duration.zero
        ? (_duration.inSeconds * 0.28 / 60).ceil().clamp(1, 999)
        : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Real transcription takes a while'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estMinutes != null
                  ? 'This file is ${_formatDuration(_duration)} long. In release mode, expect '
                      'roughly $estMinutes minute${estMinutes == 1 ? '' : 's'} of processing.'
                  : 'This could take a while, depending on how long the file is.',
            ),
            const SizedBox(height: 10),
            const Text(
              'There\'s currently no way to cancel once it starts, other than '
              'force-closing the app - only start it if you can wait it out, '
              'ideally on Wi-Fi and charging.',
            ),
            if (!kReleaseMode) ...[
              const SizedBox(height: 10),
              const Text(
                'Also: this app is running in DEBUG mode right now, which is '
                'dramatically slower. Consider stopping and running with '
                '--release instead.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Transcribing'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Tries to recognize a Bible book from the file's title (e.g.
  /// "02_Exodus") and offers two alternatives to transcribing: read the
  /// real text aloud with a synthetic TTS voice instead of this recording
  /// ('readScripture'), or - when this recording's own voice is worth
  /// keeping - caption it with the real text while this file keeps playing
  /// ('scriptureCaption'). Round 31: trimmed down to the essentials - the
  /// old version's length/can't-cancel warning (only relevant to
  /// Transcribe Anyway) moved to _confirmWhisperTiming above, and each
  /// option's explanation shrunk to one line. All three action buttons
  /// share the same plain style now (previously "Caption with Real Text"
  /// was visually bolder than the other two, which read as inconsistent).
  /// Returns 'proceed', 'readScripture', 'scriptureCaption', or null
  /// (cancelled).
  Future<String?> _confirmSlowCaptionRun() async {
    final guessedBookId = _bibleText.findBookId(widget.audioTitle);
    final guessedBookName = guessedBookId != null ? _bibleText.bookNameForId(guessedBookId) : null;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate captions?'),
        content: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guessedBookName != null
                      ? 'This looks like the Book of $guessedBookName.'
                      : 'Is this a Bible passage?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transcribe Anyway - real speech-to-text on this recording, slower, works on anything.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  'Caption with Real Text - keeps THIS recording\'s own voice, instant.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  'Read Scripture Instead - switches to a computer voice reading from scratch.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await _confirmWhisperTiming();
              if (confirmed && context.mounted) Navigator.pop(context, 'proceed');
            },
            icon: const Icon(Icons.graphic_eq, size: 20),
            label: const Text('Transcribe Anyway'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'scriptureCaption'),
            icon: const Icon(Icons.subtitles, size: 20),
            label: const Text('Caption with Real Text'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'readScripture'),
            icon: const Icon(Icons.menu_book, size: 20),
            label: Text(guessedBookName != null ? 'Read Scripture Instead' : 'Choose Scripture'),
          ),
        ],
      ),
    );
    return choice;
  }

  /// Manually picks which book of the Bible this recording is - shown as a
  /// fallback when the file's title didn't obviously name one (see
  /// BibleTextService.findBookId), so "Caption with Real Text" always works
  /// instead of silently doing nothing when the guess comes back empty.
  /// Returns the book name (matching BibleTextService.bookOrder), or null
  /// if cancelled.
  Future<String?> _pickBook() async {
    var selected = BibleTextService.bookOrder.first;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Which book of the Bible?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The file\'s name didn\'t say which book this is - pick it here so '
                  'the real text can be pulled in.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Book',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final name in BibleTextService.bookOrder)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) => setDialogState(() => selected = v ?? selected),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCaptions() async {
    if (_audioFile == null || _generatingCaptions) return;

    final choice = await _confirmSlowCaptionRun();
    if (choice == null || !mounted) return;

    if (choice == 'readScripture') {
      final guessedBookId = _bibleText.findBookId(widget.audioTitle);
      final guessedBookName = guessedBookId != null ? _bibleText.bookNameForId(guessedBookId) : null;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReadScriptureScreen(initialBook: guessedBookName)),
      );
      return;
    }

    if (choice == 'scriptureCaption') {
      var guessedBookId = _bibleText.findBookId(widget.audioTitle);
      var guessedBookName = guessedBookId != null ? _bibleText.bookNameForId(guessedBookId) : null;
      if (guessedBookId == null || guessedBookName == null) {
        // Title didn't name a recognizable book - ask instead of silently
        // doing nothing (the old behavior when the guess came back empty).
        final picked = await _pickBook();
        if (picked == null || !mounted) return;
        guessedBookName = picked;
        guessedBookId = _bibleText.bookIdFor(picked);
      }
      await _generateScriptureCaptions(guessedBookId, guessedBookName);
      return;
    }

    setState(() {
      _generatingCaptions = true;
      _captionProgress = 0;
      _captionElapsedSeconds = 0;
    });

    // Ticks every second on its own, independent of whisper's own progress
    // callback. If this counter is still climbing, the app is alive and
    // working - even if the caption text and percent aren't changing yet.
    // If it ever stops climbing, that means the screen has actually locked
    // up (not just "still processing a long file").
    _captionTimer?.cancel();
    _syncSaveTimer?.cancel();
    _captionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _captionElapsedSeconds++);
    });

    // Keep the screen from timing out (and Android from suspending the app
    // in the background) for the whole run - this is what makes "start it
    // tonight and walk away" actually reliable instead of risking a
    // half-finished transcript if the tablet locks itself partway through.
    await WakelockPlus.enable();

    try {
      final segs = await _transcripts.generateFromAudioFile(
        audioFileId: widget.audioFileId,
        audioPath: _audioFile!.path,
        onProgress: (percent) {
          // Only rebuild the screen when the number actually changes -
          // whisper can fire this rapidly, and re-rendering every single
          // call adds unnecessary UI work on top of an already CPU-heavy
          // background task.
          if (mounted && percent != _captionProgress) {
            setState(() => _captionProgress = percent);
          }
        },
      );

      // Whisper captions are saved into their own slot (see
      // TranscriptService.saveKind) - this no longer overwrites a scripture-
      // synced set that might already exist for this file.
      final updated = _audioFile!.copyWith(
        transcriptReady: true,
        hasWhisperCaptions: true,
        activeCaptionKind: 'whisper',
      );
      final all = await _storage.loadAudioFiles();
      final idx = all.indexWhere((f) => f.id == updated.id);
      if (idx >= 0) {
        all[idx] = updated;
        await _storage.saveAudioFiles(all);
      }

      _captionTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _audioFile = updated;
        _bundle = TranscriptBundle(whisper: segs, scripture: _bundle.scripture);
        _segments = segs;
        _updateCaption(_position);
        _generatingCaptions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Real captions ready')),
      );
    } catch (e) {
      _captionTimer?.cancel();
      if (!mounted) return;
      setState(() => _generatingCaptions = false);
      final message = e.toString();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Captions failed'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      await WakelockPlus.disable();
    }
  }

  /// Builds captions from the real Berean Standard Bible text instead of
  /// running Whisper - instant, and this recording's own voice keeps
  /// playing (unlike "Read Scripture Instead", which switches over to a
  /// synthetic TTS voice reading from scratch). Timing is only an estimate:
  /// there's no way to know exactly when this particular reader/translation
  /// says each verse, so each verse's slice of time is sized proportional
  /// to its word count and laid end-to-end across the file's total length.

  Future<bool> _pickCaptionTranslation() async {
    final map = await BibleTextService.allTranslations();
    if (!mounted) return false;
    String selected = map.containsKey(_captionTranslation) ? _captionTranslation : 'bsb';
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Caption translation'),
        content: StatefulBuilder(
          builder: (context, setSt) => DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Text shown over the MP3',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in map.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setSt(() => selected = v ?? selected),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Use this'),
          ),
        ],
      ),
    );
    if (picked == null || picked.isEmpty) return false;
    await _settings.setCaptionTranslation(picked);
    if (mounted) setState(() => _captionTranslation = picked);
    return true;
  }

  Future<void> _generateScriptureCaptions(String bookId, String bookName) async {
    if (_audioFile == null) return;
    final totalDuration = _audioFile!.duration > Duration.zero ? _audioFile!.duration : _duration;
    if (totalDuration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect this file\'s length yet - let it start playing once, then try again.'),
        ),
      );
      return;
    }

    final ok = await _pickCaptionTranslation();
    if (!ok || !mounted) return;

    int? chapterCount;
    try {
      chapterCount = await _bibleText.chapterCount(bookId, _captionTranslation);
    } catch (_) {
      chapterCount = null; // Offline/no cache yet - the picker below falls back to a generous range.
    }
    if (!mounted) return;

    final range = await _pickChapterRange(bookName, chapterCount);
    if (range == null || !mounted) return;
    final startChapter = range[0];
    final endChapter = range[1];
    final leadInSeconds = range.length > 2 ? range[2] : 0;

    setState(() {
      _generatingCaptions = true;
      _captionProgress = 0;
      _captionElapsedSeconds = 0;
    });
    _captionTimer?.cancel();
    _captionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _captionElapsedSeconds++);
    });

    try {
      final verses = <BibleVerse>[];
      final chapterSpan = endChapter - startChapter + 1;
      for (var chapter = startChapter; chapter <= endChapter; chapter++) {
        final chapterVerses = await _bibleText.fetchChapter(bookId, chapter, _captionTranslation);
        verses.addAll(chapterVerses);
        if (mounted) {
          setState(() => _captionProgress = (((chapter - startChapter + 1) / chapterSpan) * 100).round());
        }
      }
      if (verses.isEmpty) {
        throw Exception(
          'No verse text came back for $bookName $startChapter'
          '${endChapter != startChapter ? '-$endChapter' : ''} (Berean Standard Bible).',
        );
      }

      final segments = _buildProportionalSegments(
        verses,
        totalDuration,
        leadIn: Duration(seconds: leadInSeconds),
      );
      await _transcripts.saveKind(widget.audioFileId, 'scripture', segments);

      // Saved into its own slot - any existing Whisper transcript for this
      // file is untouched. Estimated timing - reset any previous sync
      // correction, since it was tuned for the old segment timings, not
      // these freshly-generated ones.
      final updated = _audioFile!.copyWith(
        transcriptReady: true,
        hasScriptureCaptions: true,
        activeCaptionKind: 'scripture',
        captionSyncOffsetMs: 0,
      );
      final all = await _storage.loadAudioFiles();
      final idx = all.indexWhere((f) => f.id == updated.id);
      if (idx >= 0) {
        all[idx] = updated;
        await _storage.saveAudioFiles(all);
      }

      _captionTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _audioFile = updated;
        _bundle = TranscriptBundle(whisper: _bundle.whisper, scripture: segments);
        _segments = segments;
        _captionSyncOffsetMs = 0;
        _updateCaption(_position);
        _generatingCaptions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captions ready - timing is estimated, not word-for-word synced')),
      );
    } catch (e) {
      _captionTimer?.cancel();
      if (!mounted) return;
      setState(() => _generatingCaptions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build scripture captions: $e')),
      );
    }
  }

  /// Splits [verses] across [totalDuration] proportional to each verse's
  /// word count - a short verse ("Jesus wept.") gets a short slice, a long
  /// one gets a long slice. This is a pacing guess, not a real timestamp.
  ///
  /// [leadIn] is how much of the file's front is silence/music before the
  /// actual reading starts (round 31 - many podcast-style clips have an
  /// intro) - without this, the word-count shares get spread across the
  /// WHOLE file including that dead air, which pushes every verse's timing
  /// later and later the further into the file you go. Verses are instead
  /// proportioned across just [totalDuration] minus [leadIn], then every
  /// segment is shifted forward by [leadIn] - so segment 1 starts right
  /// when the real reading does, not at 0:00. A [leadIn] as long as (or
  /// longer than) the whole file is ignored rather than producing a
  /// zero/negative span.
  List<TranscriptSegment> _buildProportionalSegments(
    List<BibleVerse> verses,
    Duration totalDuration, {
    Duration leadIn = Duration.zero,
  }) {
    final usableLeadIn = leadIn < totalDuration ? leadIn : Duration.zero;
    final speakingDuration = totalDuration - usableLeadIn;

    final wordCounts = verses.map((v) {
      final count = v.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      return count > 0 ? count : 1; // guard against a stray empty verse skewing the total to zero
    }).toList();
    final totalWords = wordCounts.fold<int>(0, (a, b) => a + b);
    final segments = <TranscriptSegment>[];
    var elapsedMs = 0; // relative to the start of SPEECH, not the file
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      final isLast = i == verses.length - 1;
      final share = totalWords == 0 ? 1 / verses.length : wordCounts[i] / totalWords;
      var endMs = isLast
          ? speakingDuration.inMilliseconds
          : elapsedMs + (speakingDuration.inMilliseconds * share).round();
      if (endMs < elapsedMs) endMs = elapsedMs;
      if (endMs > speakingDuration.inMilliseconds) endMs = speakingDuration.inMilliseconds;
      segments.add(TranscriptSegment(
        start: usableLeadIn + Duration(milliseconds: elapsedMs),
        end: usableLeadIn + Duration(milliseconds: endMs),
        text: '${v.chapter}:${v.verse} ${v.text}',
      ));
      elapsedMs = endMs;
    }
    return segments;
  }

  /// Asks which chapter(s) of [bookName] this recording covers - the title
  /// only tells us the book, not the chapter(s), and a recording might be
  /// one chapter or a whole section read straight through. Defaults to
  /// chapter 1 through chapter 1; bumping "Starting chapter" up moves
  /// "Through chapter" up to match, so it can't end up before the start.
  /// Also asks how many seconds of silence/music sit at the very front
  /// before the actual reading starts (round 31 - common on podcast-style
  /// clips) - see _buildProportionalSegments' [leadIn] param for why this
  /// matters. Returns [start, end, leadInSeconds], or null if cancelled.
  Future<List<int>?> _pickChapterRange(String bookName, int? chapterCount) async {
    var start = 1;
    var end = 1;
    final leadInController = TextEditingController();
    final maxChapter = chapterCount ?? 150; // generous fallback if offline/uncached - Psalms tops out at 150
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Which chapter(s) of $bookName?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This just tells us which text to pull in - it doesn\'t need to be exact.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: start,
                        decoration: const InputDecoration(
                          labelText: 'Starting chapter',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var c = 1; c <= maxChapter; c++) DropdownMenuItem(value: c, child: Text('$c')),
                        ],
                        onChanged: (v) => setDialogState(() {
                          start = v ?? start;
                          if (end < start) end = start;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // Remounts whenever the valid range shifts (start moves, or the
                        // count needs clamping) so its displayed value and item list
                        // always agree - a DropdownButtonFormField's initialValue is
                        // only read once at mount otherwise.
                        key: ValueKey('endChapter_${start}_$maxChapter'),
                        initialValue: end,
                        decoration: const InputDecoration(
                          labelText: 'Through chapter',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var c = start; c <= maxChapter; c++) DropdownMenuItem(value: c, child: Text('$c')),
                        ],
                        onChanged: (v) => setDialogState(() => end = v ?? end),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: leadInController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Silence/intro before it starts talking? (seconds)',
                    border: OutlineInputBorder(),
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'If there\'s music or dead air at the start before the reading '
                  'actually begins, put roughly how many seconds here - captions '
                  'won\'t start advancing until then. Leave blank if it starts '
                  'talking right away.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final leadIn = int.tryParse(leadInController.text.trim()) ?? 0;
                Navigator.pop(context, [start, end, leadIn < 0 ? 0 : leadIn]);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    leadInController.dispose();
    return result;
  }

  Future<void> _showExport() async {
    final plain = _export.toPlainText(
      sessionLabel: widget.sessionLabel,
      audioTitle: widget.audioTitle,
      notes: _notes,
    );
    final outline = _export.toOutline(
      sessionLabel: widget.sessionLabel,
      audioTitle: widget.audioTitle,
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _interruptSub?.cancel();
    _captionTimer?.cancel();
    _recordingTimer?.cancel();
    _continuousSeekTimer?.cancel();
    _voiceRecorder.dispose();
    if (_generatingCaptions) {
      // Defensive - if the screen is left mid-generation, don't leave the
      // screen wakelock stuck on forever.
      WakelockPlus.disable();
    }
    _savePosition();
    _audio.dispose();
    super.dispose();
  }

  String _formatElapsed(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  /// A big round icon button with a color and a short label underneath -
  /// used for the whole transport row (Pause/Stop/Play) plus secondary
  /// actions (Mute, Type Note), so every button in this screen reads the
  /// same way: color + icon + label, easy to tell apart at a glance.
  /// [onPressed] null both disables the button and (since the color would
  /// otherwise look identical whether usable or not) falls back to the
  /// theme's normal disabled styling instead of the custom [background].
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
    // The bevelled key itself now lives in widgets/stereo_panel.dart, shared
    // with the TTS player so both screens' buttons stay identical.
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.sessionLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

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
              widget.audioTitle,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _generatingCaptions ? null : () async {
              await _pickCaptionTranslation();
            },
            child: Text(
              (_captionTranslation.startsWith('local_')
                      ? _captionTranslation.substring(6)
                      : _captionTranslation)
                  .toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            iconSize: 30,
            icon: _generatingCaptions
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _captionProgress > 0 ? _captionProgress / 100 : null,
                    ),
                  )
                : Icon(
                    Icons.closed_caption,
                    size: 30,
                    color: (_audioFile?.transcriptReady ?? false) ? theme.colorScheme.primary : null,
                  ),
            tooltip: _generatingCaptions
                ? 'Generating captions… $_captionProgress%'
                : (_audioFile?.transcriptReady ?? false)
                    ? 'Regenerate real captions'
                    : 'Generate real captions (one-time model download)',
            onPressed: _generatingCaptions ? null : _generateCaptions,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt, size: 30),
            tooltip: 'Outline / Export',
            onPressed: _showExport,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        // Round 33 fix: the growing dial card / transport card (bigger knob,
        // carbon panels, the oversized straddling PAUSE key, the Screen
        // Nudge module) pushed this screen's total content height past what
        // several phone screens can show. It used to rely on Expanded/flex
        // to fit everything into exactly one screen with no scrolling - but
        // once the non-flex content got tall enough, the flex-based caption
        // box and notes list would collapse to near-zero height (or get
        // pushed off-screen) with NO error shown in release builds, which is
        // exactly what caused "no reading box, no play buttons" after the
        // last rebuild. Wrapping the whole body in a scroll view means it
        // can never silently disappear again - worst case, you scroll.
        child: SingleChildScrollView(
          child: Column(
          children: [
            if (_generatingCaptions)
              Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Expanded(
                          child: Text(
                            'Generating captions… ${_formatElapsed(_captionElapsedSeconds)} elapsed'
                            '${_captionProgress > 0 ? ' ($_captionProgress%)' : ''}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2),
                      child: Text(
                        'Long files can take a long time - as long as the timer above is '
                        'still counting up, it\'s working, not stuck. You can keep listening.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            // Round 34: caption box height increased (260 -> 310) so one
            // more line of the passage is visible at once. Still a fixed
            // height inside the scroll view so controls never get pushed
            // off-screen on smaller devices.
            Builder(
              builder: (context) {
                final h = MediaQuery.sizeOf(context).shortestSide < 600 ? 168.0 : 240.0;
                return Container(
                width: double.infinity,
                height: h,
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
                      _currentCaption,
                      style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                );
              },
            ),
            // Only shown once BOTH caption sets exist for this file - lets
            // you pick which one is currently playing instead of one
            // silently overwriting the other.
            if ((_audioFile?.hasWhisperCaptions ?? false) && (_audioFile?.hasScriptureCaptions ?? false))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Whisper transcript'),
                      selected: _audioFile!.activeCaptionKind == 'whisper',
                      onSelected: (_) => _switchCaptionKind('whisper'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Real scripture text'),
                      selected: _audioFile!.activeCaptionKind == 'scripture',
                      onSelected: (_) => _switchCaptionKind('scripture'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Slider(
                    value: _duration.inMilliseconds == 0
                        ? 0
                        : _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                    max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (v) async {
                      final newPos = Duration(milliseconds: v.toInt());
                      await _audio.seek(newPos);
                      setState(() {
                        _position = newPos;
                        _updateCaption(newPos);
                      });
                    },
                    onChangeEnd: (_) => _savePosition(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position)),
                      Text(_formatDuration(_duration)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Round 33: Speed and Nudge Captions now share one card
                  // with a divider (see _dialCard) instead of two separate
                  // side-by-side cards.
                  _dialCard(theme),
                ],
              ),
            ),
            // Round 33: Stop / rewind / Play-Pause / forward / skip-length
            // now live together in one card (see _transportCard), replacing
            // the old two-row layout (Stop/Record-Note/Play, then a
            // separate 15s-skip row).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: _transportCard(theme),
            ),
            // Secondary controls - just Mute and Type Note now. Record Note
            // is gone from here: PAUSE in the transport card above IS the
            // record-a-note button (it pauses and starts recording, and
            // carries a mic glyph to say so), so a second button doing the
            // identical thing was redundant.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _labeledIconButton(
                    theme: theme,
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    label: 'MUTE',
                    onPressed: _toggleMute,
                    background: theme.colorScheme.secondaryContainer,
                    foreground: theme.colorScheme.onSecondaryContainer,
                    size: 64,
                    iconSize: 28,
                  ),
                  const SizedBox(width: 32),
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
                  // The deck's backlight trim switch.
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
                        'Notes appear here.\nTap Type note to add one with a timestamp.',
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
                              child: Text(
                                _formatDuration(n.timestamp).split(':').first,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              n.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${_formatDuration(n.timestamp)}  •  ${n.captionContext.length > 50 ? '${n.captionContext.substring(0, 50)}…' : n.captionContext}',
                              maxLines: 2,
                            ),
                            onTap: () async {
                              await _audio.seek(n.timestamp);
                              setState(() {
                                _position = n.timestamp;
                                _updateCaption(n.timestamp);
                              });
                            },
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
