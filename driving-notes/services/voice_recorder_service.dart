import 'package:record/record.dart';

/// Thin wrapper around the `record` package for short spoken notes.
/// Kept separate from TranscriptService (which handles turning the
/// recorded clip into text) so recording and transcription can be
/// tested/replaced independently.
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Prompts for microphone permission if not already granted.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start(String path) async {
    await _recorder.start(const RecordConfig(), path: path);
  }

  /// Stops recording and returns the path to the saved clip, or null if
  /// nothing was recording.
  Future<String?> stop() => _recorder.stop();

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
  }
}
