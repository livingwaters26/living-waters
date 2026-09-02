import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/emphasis_service.dart';
import '../services/settings_service.dart';
import '../services/simple_storage.dart';
import '../services/voice_recorder_service.dart';
import 'player_screen.dart';
import 'teleprompter_passage_picker.dart';
import 'teleprompter_view.dart';

/// Standalone long-form recorder - separate from the short pause-to-record
/// voice notes used elsewhere in the app. This is for reading through a
/// whole passage yourself and saving it as a real audio file in the
/// library, in whichever collection you choose (e.g. "Personal Readings"),
/// ready to play back, caption, and take notes on just like an imported
/// MP3.
class RecordReadingScreen extends StatefulWidget {
  const RecordReadingScreen({super.key});

  @override
  State<RecordReadingScreen> createState() => _RecordReadingScreenState();
}

class _RecordReadingScreenState extends State<RecordReadingScreen> {
  final _storage = SimpleStorage();
  final _voiceRecorder = VoiceRecorderService();

  // What you're about to read (e.g. "John 3") - typed BEFORE hitting Start,
  // so it's on your mind while you're setting up, not an afterthought once
  // you've already stopped. Combined with a timestamp to build the title.
  final _nameController = TextEditingController();

  bool _isRecording = false;
  int _elapsedSeconds = 0;
  bool _blinkOn = true;
  Timer? _timer;

  // Optional teleprompter - loaded ahead of time (via TeleprompterPassagePicker)
  // so it's ready the moment recording starts. Null means "just record" -
  // the plain flow above works exactly as it always has when this is unset.
  // Everything about HOW the teleprompter scrolls - pacing, font size,
  // countdown, pause state - lives inside TeleprompterView itself. This
  // screen only tracks which passage is loaded and whether we're recording
  // or rehearsing.
  List<BibleVerse>? _teleprompterVerses;
  String? _teleprompterLabel;

  // Runs the teleprompter WITHOUT recording, so a passage's pace can be
  // dialed in before committing to a take.
  bool _practicing = false;

  // Optional AI-assisted delivery help layered on top of a loaded
  // teleprompter passage - never changes the text itself, only suggests
  // where to lean in for emphasis or take a breath. See EmphasisService for
  // how "never changes the wording" is actually enforced, not just assumed.
  final _settings = SettingsService();
  final _emphasis = EmphasisService();
  List<EmphasisMark>? _emphasisMarks;
  bool _analyzingEmphasis = false;

  // Real phone calls are reported by Android the same way our OWN recorder
  // taking the microphone is - suppress while we're the ones causing it, so
  // a routine recording isn't mistaken for an incoming call. A REAL
  // interruption while recording stops and saves what's been captured.
  StreamSubscription<AudioInterruptionEvent>? _interruptSub;
  bool _suppressInterruptions = false;

  @override
  void initState() {
    super.initState();
    _initInterruptionHandling();
  }

  Future<void> _initInterruptionHandling() async {
    final session = await AudioSession.instance;
    _interruptSub = session.interruptionEventStream.listen((event) async {
      if (_suppressInterruptions) return;
      if (event.begin && _isRecording) {
        await _stopAndSave(autoSavedDueToCall: true);
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSave();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _voiceRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is needed to record.')),
          );
        }
        return;
      }

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'recordings'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final path = p.join(dir.path, '${const Uuid().v4()}.m4a');

      _suppressInterruptions = true;
      await _voiceRecorder.start(path);

      _timer?.cancel();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _elapsedSeconds = 0;
          _blinkOn = true;
        });
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
            _blinkOn = !_blinkOn;
          });
        }
      });
      // A long reading is exactly the situation where Android's screen
      // timeout bites: the display sleeps, the teleprompter disappears
      // mid-sentence, and the recording keeps running blind. Hold the
      // screen awake for the whole take, released again on stop.
      await WakelockPlus.enable();
    } catch (e) {
      _suppressInterruptions = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSave({bool autoSavedDueToCall = false}) async {
    _timer?.cancel();
    await WakelockPlus.disable();
    // Focus events from releasing the recorder can lag slightly behind the
    // stop() call itself - stay suppressed a moment longer.
    Future.delayed(const Duration(milliseconds: 800), () {
      _suppressInterruptions = false;
    });

    final wasElapsed = _elapsedSeconds;
    String? path;
    try {
      path = await _voiceRecorder.stop();
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop recording: $e')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isRecording = false);

    if (path == null || wasElapsed < 1) return; // Nothing meaningful captured.

    if (autoSavedDueToCall && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paused for phone call - your reading was stopped and saved.'),
        ),
      );
    }

    await _saveDialog(path);
  }

  /// Combines whatever the user typed before recording (e.g. "John 3") with
  /// a date+time stamp - falls back to a plain "Reading" title if they left
  /// it blank, so there's always a sensible default either way.
  String _defaultTitle() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final stamp = '${now.month}/${now.day}/${now.year} $h:$m $ampm';
    final name = _nameController.text.trim();
    return name.isEmpty ? 'Reading – $stamp' : '$name – $stamp';
  }

  Future<void> _saveDialog(String path) async {
    final defaultTitle = _defaultTitle();
    final titleController = TextEditingController(text: defaultTitle);
    var collections = await _storage.loadCollectionNames();
    var selectedCollection =
        collections.contains('Personal Readings') ? 'Personal Readings' : collections.first;

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Save your reading'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCollection,
                  decoration: const InputDecoration(labelText: 'Save to'),
                  items: [
                    ...collections.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    const DropdownMenuItem(value: '__new__', child: Text('+ New collection…')),
                  ],
                  onChanged: (v) async {
                    if (v == '__new__') {
                      final name = await _promptNewCollectionName(dialogContext);
                      if (name != null && name.isNotEmpty) {
                        await _storage.addCollectionName(name);
                        collections = await _storage.loadCollectionNames();
                        setDialogState(() => selectedCollection = name);
                      }
                    } else if (v != null) {
                      setDialogState(() => selectedCollection = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await File(path).delete();
                } catch (_) {
                  // Best effort - not worth blocking on.
                }
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final title = titleController.text.trim().isEmpty ? defaultTitle : titleController.text.trim();
    final audio = AudioFile(
      path: path,
      title: title,
      duration: Duration.zero,
      collection: selectedCollection,
    );
    await _storage.addAudioFile(audio);

    final session = Session(audioFileId: audio.id, label: title);
    await _storage.addSession(session);

    // Clear the "what you're reading" field and any loaded teleprompter
    // passage now that they've been used, so the next recording starts
    // fresh instead of reusing this chapter's name/text.
    _nameController.clear();
    _teleprompterVerses = null;
    _teleprompterLabel = null;
    _emphasisMarks = null;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          audioFileId: audio.id,
          sessionId: session.id,
          sessionLabel: session.label,
          audioTitle: title,
        ),
      ),
    );
  }

  Future<String?> _promptNewCollectionName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Personal Readings, NIV Dramatized'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTeleprompterPassage() async {
    final result = await Navigator.of(context).push<TeleprompterPassage>(
      MaterialPageRoute(builder: (_) => const TeleprompterPassagePicker()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _teleprompterVerses = result.verses;
      _teleprompterLabel = result.label;
      _emphasisMarks = null; // belongs to whatever passage was loaded before
      // Only fill the name if it's still blank - don't clobber something
      // already typed.
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _teleprompterLabel!;
      }
    });
  }

  void _removeTeleprompterPassage() {
    setState(() {
      _teleprompterVerses = null;
      _teleprompterLabel = null;
      _emphasisMarks = null;
    });
  }

  /// Asks for (or lets you change) the Anthropic API key the "Analyze for
  /// Emphasis" feature uses. Stored locally on this device only
  /// (SettingsService), never sent anywhere except directly to Anthropic's
  /// API alongside the actual request.
  Future<String?> _promptForApiKey({bool alreadyHasOne = false}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(alreadyHasOne ? 'Update API Key' : 'AI Emphasis Setup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alreadyHasOne
                    ? 'Paste a new Anthropic API key to replace the saved one, or '
                        'Clear to remove it.'
                    : 'This feature sends your loaded text to Claude (Anthropic\'s '
                        'AI) once, just to suggest emphasis and pause points - it '
                        'never rewrites the text itself. It needs an Anthropic API '
                        'key from console.anthropic.com (pay-as-you-go; a chapter-'
                        'sized passage typically costs well under a penny). Paste '
                        'your key below - it\'s saved only on this device.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'sk-ant-...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (alreadyHasOne)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeApiKey() async {
    final existing = await _settings.getAnthropicApiKey();
    final entered = await _promptForApiKey(alreadyHasOne: existing != null);
    if (entered == null) return; // cancelled
    await _settings.setAnthropicApiKey(entered.isEmpty ? null : entered);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(entered.isEmpty ? 'API key removed.' : 'API key saved.')),
    );
  }

  /// Sends the loaded teleprompter text to Claude once to get back emphasis
  /// and pause suggestions - see EmphasisService for the safety design that
  /// guarantees this can only add styling, never change a single word of
  /// the text you're about to read.
  Future<void> _analyzeEmphasis() async {
    final verses = _teleprompterVerses;
    if (verses == null || _analyzingEmphasis) return;

    final savedKey = await _settings.getAnthropicApiKey();
    String key;
    if (savedKey == null) {
      if (!mounted) return;
      final entered = await _promptForApiKey();
      if (entered == null || entered.isEmpty) return;
      await _settings.setAnthropicApiKey(entered);
      key = entered;
    } else {
      key = savedKey;
    }

    setState(() => _analyzingEmphasis = true);
    try {
      final marks = await _emphasis.analyze(chunks: verses, apiKey: key);
      if (!mounted) return;
      setState(() {
        _emphasisMarks = marks;
        _analyzingEmphasis = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            marks.isEmpty
                ? 'No suggestions came back - it\'ll read plainly, nothing else changed.'
                : 'Got it - bold words are emphasis suggestions, "·" marks a good place to pause.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzingEmphasis = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get emphasis suggestions: $e')),
      );
    }
  }

  /// Runs the teleprompter with no recording at all - purely to rehearse a
  /// passage and find a comfortable speed before spending a real take on it.
  void _startPractice() {
    if (_teleprompterVerses == null) return;
    setState(() => _practicing = true);
    WakelockPlus.enable();
  }

  void _stopPractice() {
    WakelockPlus.disable();
    setState(() => _practicing = false);
  }


  String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interruptSub?.cancel();
    _voiceRecorder.dispose();
    _nameController.dispose();
    // Best effort - never let a stale wakelock outlive this screen.
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The teleprompter needs a bounded-height scrolling viewport, which
    // doesn't fit inside the plain flow's SingleChildScrollView below - so
    // recording-with-a-loaded-passage gets its own dedicated layout
    // entirely. Everything else (idle state, and recording with no
    // passage loaded) is completely unchanged from before this existed.
    if ((_isRecording || _practicing) && _teleprompterVerses != null) {
      return TeleprompterView(
        // Rebuilt from scratch whenever the passage changes, so its own
        // scroll/pace state always matches what's on screen.
        key: ValueKey(_teleprompterLabel),
        verses: _teleprompterVerses!,
        label: _teleprompterLabel ?? 'Reading',
        emphasisMarks: _emphasisMarks,
        isPractice: _practicing,
        elapsedSeconds: _elapsedSeconds,
        blinkOn: _blinkOn,
        onStop: _practicing ? _stopPractice : _toggleRecording,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Record a Reading')),
      body: SafeArea(
        // Scrollable (not just centered) now that there's a text field on
        // this screen - so the keyboard popping up to type a name can never
        // push the Start Recording button off the bottom of the screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (!_isRecording) ...[
                Icon(Icons.mic_none, size: 88, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Read a passage aloud and save it as your own audio file - it plays back, '
                  'gets captioned, and takes notes just like an imported MP3, in whichever '
                  'collection you choose (e.g. "Personal Readings").',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'What are you reading? (optional)',
                    hintText: 'e.g. John 3, Psalm 23',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Name it before you start so it\'s ready to go - a timestamp is added '
                  'automatically when it\'s saved.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
                // Entirely optional - reading straight into the mic with
                // nothing loaded works exactly like it always has.
                if (_teleprompterVerses == null)
                  OutlinedButton.icon(
                    onPressed: _pickTeleprompterPassage,
                    icon: const Icon(Icons.auto_stories),
                    label: const Text('Add a Teleprompter (optional)'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_stories, color: theme.colorScheme.onPrimaryContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Teleprompter ready: $_teleprompterLabel',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _removeTeleprompterPassage,
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        // Optional, needs internet + a one-time API key -
                        // never touches the actual wording, only suggests
                        // where to emphasize/pause. See EmphasisService.
                        Row(
                          children: [
                            Expanded(
                              child: _analyzingEmphasis
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Getting emphasis suggestions…'),
                                        ],
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _analyzeEmphasis,
                                      icon: const Icon(Icons.auto_awesome, size: 18),
                                      label: Text(
                                        _emphasisMarks == null
                                            ? 'Analyze for Emphasis (AI, optional)'
                                            : 'Re-analyze (${_emphasisMarks!.length} tips)',
                                      ),
                                    ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.vpn_key_outlined),
                              tooltip: 'AI API key settings',
                              color: theme.colorScheme.onPrimaryContainer,
                              onPressed: _changeApiKey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                if (_nameController.text.trim().isNotEmpty) ...[
                  Text(
                    _nameController.text.trim(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                ],
                AnimatedOpacity(
                  opacity: _blinkOn ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 400),
                  child: Icon(Icons.fiber_manual_record, size: 96, color: theme.colorScheme.error),
                ),
                const SizedBox(height: 20),
                Text(
                  'RECORDING - ${_formatElapsed(_elapsedSeconds)}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 72),
                    backgroundColor: _isRecording ? theme.colorScheme.error : null,
                    foregroundColor: _isRecording ? theme.colorScheme.onError : null,
                  ),
                  icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, size: 30),
                  label: Text(_isRecording ? 'Stop & Save' : 'Start Recording'),
                ),
              ),
              // Rehearsal costs nothing and saves nothing - the point is to
              // find a comfortable speed before spending a real take on it.
              if (!_isRecording && _teleprompterVerses != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startPractice,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Practice (no recording)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
