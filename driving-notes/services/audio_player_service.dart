import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Handles playing the MP3, tracking position, mute, and phone-call interruptions.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;
  double _volumeBeforeMute = 1.0;
  bool _wasPlayingBeforeInterruption = false;

  // The app's OWN voice-note recorder taking/releasing the microphone looks
  // identical to Android as a real phone call taking audio focus. Whoever
  // starts/stops that recorder should set this true beforehand and clear it
  // once focus has settled, so a routine voice note doesn't get mistaken
  // for an incoming call.
  bool _suppressInterruptions = false;

  void setSuppressInterruptions(bool suppress) {
    _suppressInterruptions = suppress;
  }

  /// Called when a phone call (or other high-priority audio) starts or ends.
  /// PlayerScreen can listen and also stop the voice-note recorder.
  final StreamController<bool> _interruptionController =
      StreamController<bool>.broadcast();

  /// true = interrupted (call started), false = interruption ended
  Stream<bool> get interruptionStream => _interruptionController.stream;

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> init() async {
    final session = await AudioSession.instance;

    // "Speech" is appropriate for scripture / spoken word.
    // Android will duck or pause us when a phone call needs the audio path.
    await session.configure(const AudioSessionConfiguration.speech());

    // When another app (phone, Maps voice, etc.) needs audio:
    session.interruptionEventStream.listen((event) async {
      if (_suppressInterruptions) {
        // Our own recorder taking/releasing focus, not a real call - ignore.
        return;
      }
      if (event.begin) {
        // Call starting (or other interruption)
        _wasPlayingBeforeInterruption = _player.playing;
        if (_player.playing) {
          await _player.pause();
        }
        // Force volume down as well so nothing leaks into the call
        if (!_isMuted) {
          _volumeBeforeMute = _player.volume;
          await _player.setVolume(0);
        }
        _interruptionController.add(true);
      } else {
        // Call ended
        if (!_isMuted) {
          await _player.setVolume(_volumeBeforeMute);
        }
        _interruptionController.add(false);
        // We do NOT auto-resume. User may still be talking or want to stay paused.
        // They tap Play when ready.
      }
    });

    // Becoming noisy (headphones unplugged) → pause
    session.becomingNoisyEventStream.listen((_) async {
      if (_player.playing) {
        await _player.pause();
      }
    });
  }

  /// Load an MP3 file from a full path on the device.
  Future<Duration?> setFile(String filePath) async {
    final duration = await _player.setFilePath(filePath);
    return duration;
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> stop() => _player.stop();

  /// Changes playback rate without changing pitch - just_audio hands this to
  /// the platform player (ExoPlayer on Android), which time-stretches rather
  /// than just resampling, so slowing down doesn't drop your voice into a
  /// slow-motion growl. 1.0 is normal speed; e.g. 0.8 plays a recording that
  /// was read quickly back at a more natural pace.
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  double get speed => _player.speed;

  bool get isMuted => _isMuted;
  bool get wasPlayingBeforeInterruption => _wasPlayingBeforeInterruption;

  Future<void> setMuted(bool muted) async {
    if (muted && !_isMuted) {
      _volumeBeforeMute = _player.volume;
      await _player.setVolume(0);
      _isMuted = true;
    } else if (!muted && _isMuted) {
      await _player.setVolume(_volumeBeforeMute);
      _isMuted = false;
    }
  }

  Future<void> toggleMute() => setMuted(!_isMuted);

  Duration get currentPosition => _player.position;

  Future<void> dispose() async {
    await _interruptionController.close();
    await _player.dispose();
  }
}
