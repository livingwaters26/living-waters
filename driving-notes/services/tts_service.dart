import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts that turns "speak this and tell me when
/// you're done" into a plain awaitable Future, so callers can read verses
/// one at a time in a simple loop instead of juggling callbacks.
///
/// Also owns the shared AudioSession for speech. This matters because
/// recording a voice note (which needs the microphone) can leave Android's
/// audio focus/session in a state where flutter_tts still reports speech as
/// "done" without ever actually making sound - re-claiming the session
/// before every speak() call fixes that "looks like it's playing but silent"
/// symptom after pausing to record a note.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  Completer<void>? _speakCompleter;
  bool _initialized = false;

  // flutter_tts's rate scale (roughly 0.0-1.0, not a "1.0 = normal speed"
  // multiplier like just_audio's) - 0.45 was the original hardcoded value
  // and stays the default "Normal" here.
  double _rate = 0.45;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    _tts.setCancelHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    _tts.setErrorHandler((message) {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    _initialized = true;
  }

  /// Speaks [text] and completes once speech actually finishes (or is
  /// stopped). Safe to call repeatedly in a loop, one sentence/verse at a
  /// time - that gives the caller a clean point to update the on-screen
  /// caption before each one starts.
  Future<void> speak(String text) async {
    await _ensureInit();
    // Re-request audio focus every time, not just once - this is what
    // reclaims the speaker after the microphone (voice note recording)
    // was in use.
    final session = await AudioSession.instance;
    await session.setActive(true);
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
    await _speakCompleter!.future;
  }

  /// Changes how fast the voice reads. Takes effect on the NEXT verse
  /// spoken, not necessarily mid-sentence - flutter_tts doesn't guarantee
  /// applying a rate change to speech already in progress.
  Future<void> setSpeechRate(double rate) async {
    _rate = rate;
    await _ensureInit();
    await _tts.setSpeechRate(rate);
  }

  double get speechRate => _rate;

  Future<void> stop() async {
    await _tts.stop();
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }

  void dispose() {
    _tts.stop();
  }
}
