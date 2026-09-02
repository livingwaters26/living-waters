import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/models.dart';

/// Timed transcripts for scrolling captions.
/// Generated on-device with Whisper (whisper_ggml / whisper.cpp).
/// The model (~60-75MB, "base" English) downloads once on first use
/// (needs internet) and is cached after that — fully offline from then on.
class TranscriptService {
  final WhisperController _whisper = WhisperController();

  /// "base" English model — good default balance of speed/accuracy for a
  /// phone or tablet. See OFFLINE_WHISPER_GUIDE.md for other options.
  static const WhisperModel model = WhisperModel.baseEn;

  Future<Directory> _transcriptDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'transcripts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileForAudio(String audioFileId) async {
    final dir = await _transcriptDir();
    return File(p.join(dir.path, '$audioFileId.json'));
  }

  /// A file can now hold TWO saved caption sets at once - real Whisper
  /// transcription and estimated "Caption with Real Text" scripture-synced
  /// captions - instead of one overwriting the other. Either side can be
  /// null if that method hasn't been run yet.
  Future<TranscriptBundle> loadBundle(String audioFileId) async {
    final file = await _fileForAudio(audioFileId);
    if (!await file.exists()) return const TranscriptBundle();
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const TranscriptBundle();
    final decoded = jsonDecode(text);

    // Legacy format from before dual captions existed: a bare JSON array,
    // not an object. Read it in as whichever kind it happens to be -
    // defaulting to 'whisper' since that was the original/only method -
    // rather than losing it. Not rewritten to disk here; the next real
    // save (from either method) moves this file to the new format on its
    // own.
    if (decoded is List) {
      final segs = decoded.map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>)).toList();
      return TranscriptBundle(whisper: segs);
    }

    final map = decoded as Map<String, dynamic>;
    List<TranscriptSegment>? parseKind(String key) {
      final raw = map[key];
      if (raw == null) return null;
      return (raw as List<dynamic>).map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>)).toList();
    }

    return TranscriptBundle(whisper: parseKind('whisper'), scripture: parseKind('scripture'));
  }

  /// Convenience for callers that just want SOMETHING to show as a preview
  /// (e.g. a caption snippet in a list) and don't care which method it
  /// came from - prefers whichever is more likely to be a full transcript.
  Future<List<TranscriptSegment>?> load(String audioFileId) async {
    final bundle = await loadBundle(audioFileId);
    return bundle.whisper ?? bundle.scripture;
  }

  Future<void> saveKind(String audioFileId, String kind, List<TranscriptSegment> segments) async {
    assert(kind == 'whisper' || kind == 'scripture');
    final bundle = await loadBundle(audioFileId);
    final whisper = kind == 'whisper' ? segments : bundle.whisper;
    final scripture = kind == 'scripture' ? segments : bundle.scripture;
    final file = await _fileForAudio(audioFileId);
    final map = {
      if (whisper != null) 'whisper': whisper.map((s) => s.toJson()).toList(),
      if (scripture != null) 'scripture': scripture.map((s) => s.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(map));
  }

  /// Legacy single-transcript save, used only by [createPlaceholder] - a
  /// placeholder isn't really "from" either method, so it goes in the
  /// 'whisper' slot arbitrarily; it gets replaced the moment either real
  /// method actually runs.
  Future<void> save(String audioFileId, List<TranscriptSegment> segments) =>
      saveKind(audioFileId, 'whisper', segments);

  /// Removes a saved transcript - used when its audio file is deleted from
  /// the library, so an orphaned caption file doesn't linger.
  Future<void> delete(String audioFileId) async {
    final file = await _fileForAudio(audioFileId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<TranscriptSegment>> createPlaceholder({
    required String audioFileId,
    required Duration duration,
    String sampleText =
        'Captions placeholder — tap the CC button to generate real captions.',
  }) async {
    const chunkSeconds = 12;
    final segments = <TranscriptSegment>[];
    var start = Duration.zero;
    var index = 1;

    while (start < duration) {
      final end = start + const Duration(seconds: chunkSeconds);
      final actualEnd = end > duration ? duration : end;
      segments.add(TranscriptSegment(
        start: start,
        end: actualEnd,
        text: '$sampleText (part $index)',
      ));
      start = actualEnd;
      index++;
      if (index > 500) break;
    }

    await save(audioFileId, segments);
    return segments;
  }

  /// Runs real on-device Whisper transcription on the whole audio file and
  /// saves timed segments for scrolling captions.
  ///
  /// First call on a device downloads the "base" English model (needs
  /// internet, ~60-75MB, one time only — prefer Wi-Fi + charging). After
  /// that the model is cached and this works fully offline.
  Future<List<TranscriptSegment>> generateFromAudioFile({
    required String audioFileId,
    required String audioPath,
    void Function(int percent)? onProgress,
  }) async {
    onProgress?.call(2);
    File? wavFile;
    int wavBytes = 0;
    try {
      if (!await File(audioPath).exists()) {
        throw Exception(
          'The source audio file is missing at $audioPath. Older imports stored a path into a '
          'TEMPORARY cache folder that Android can clear at any time - newer imports don\'t have '
          'this problem. Delete this file from My MP3s and import it again.',
        );
      }

      // Step 1: convert the source file (MP3/etc.) to a clean 16kHz mono WAV.
      final tempDir = await getTemporaryDirectory();
      wavFile = File(p.join(tempDir.path, '${audioFileId}_whisper.wav'));
      final converted = await WhisperAudioConvert(
        audioInput: File(audioPath),
        audioOutput: wavFile,
      ).convert();

      if (converted == null || !await converted.exists()) {
        throw Exception(
          'Step 1 (convert to WAV) failed: no output file was produced from $audioPath.',
        );
      }
      wavBytes = await converted.length();
      if (wavBytes < 10000) {
        // A real WAV of a spoken-word MP3 should be many MB. A file this
        // small is basically just a header - conversion silently failed.
        throw Exception(
          'Step 1 (convert to WAV) produced an almost-empty file ($wavBytes bytes) from $audioPath. '
          'The conversion likely failed silently.',
        );
      }
      onProgress?.call(15);

      // Step 2: make sure the model actually finished downloading before we
      // blame the audio for a bad result.
      String modelPath;
      try {
        modelPath = await _whisper.downloadModel(model);
      } catch (e) {
        throw Exception(
          'Step 2 (download Whisper model) failed: $e. Make sure the tablet has internet and try again.',
        );
      }
      final modelFile = File(modelPath);
      final modelExists = await modelFile.exists();
      final modelBytes = modelExists ? await modelFile.length() : 0;
      if (!modelExists || modelBytes < 10 * 1024 * 1024) {
        throw Exception(
          'Step 2 (Whisper model) looks incomplete: $modelBytes bytes at $modelPath. '
          'Try again on Wi-Fi, or delete that file and retry.',
        );
      }
      onProgress?.call(25);

      // Step 3: actually transcribe the converted WAV.
      final result = await _whisper.transcribe(
        model: model,
        audioPath: converted.path,
        lang: 'en',
        withSegments: true,
        keepModelLoaded: false,
        onProgress: (percent) {
          // Steps 1-2 used the first 25%; leave the last 5% for saving.
          onProgress?.call(25 + (percent * 70 ~/ 100));
        },
      );

      final whisperSegments = result?.transcription.segments ?? const [];
      final rawText = result?.transcription.text.trim() ?? '';
      List<TranscriptSegment> segments;
      if (whisperSegments.isNotEmpty) {
        segments = whisperSegments
            .map(
              (s) => TranscriptSegment(
                start: s.fromTs,
                end: s.toTs,
                text: s.text.trim(),
              ),
            )
            .where((s) => s.text.isNotEmpty)
            .toList();
      } else if (rawText.isNotEmpty) {
        segments = [
          TranscriptSegment(start: Duration.zero, end: const Duration(hours: 3), text: rawText),
        ];
      } else {
        // Whisper ran successfully but returned nothing at all. Surface the
        // diagnostics we gathered instead of a generic message, so we can
        // actually tell what's wrong from the error shown on screen.
        final responseType = result?.transcription.type ?? '(null response)';
        throw Exception(
          'Step 3 (transcribe) returned no text. wav=${wavBytes}B, model=${modelBytes}B, response.type="$responseType".',
        );
      }

      await saveKind(audioFileId, 'whisper', segments);
      onProgress?.call(100);
      return segments;
    } catch (e) {
      onProgress?.call(100);
      rethrow;
    } finally {
      if (wavFile != null && await wavFile.exists()) {
        try {
          await wavFile.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    }
  }

  /// Transcribes a short spoken note (recorded via VoiceRecorderService)
  /// using the same on-device Whisper model as captions. Returns readable
  /// text - never throws, so a transcription hiccup doesn't lose the voice
  /// clip itself (that's saved separately regardless of this result).
  Future<String> transcribeVoiceClip(String audioPath) async {
    File? wavFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final base = p.basenameWithoutExtension(audioPath);
      wavFile = File(p.join(tempDir.path, '${base}_note.wav'));
      final converted = await WhisperAudioConvert(
        audioInput: File(audioPath),
        audioOutput: wavFile,
      ).convert();

      if (converted == null || !await converted.exists()) {
        return '(Voice note saved, but could not be converted for transcription.)';
      }

      final result = await _whisper.transcribe(
        model: model,
        audioPath: converted.path,
        lang: 'en',
        withSegments: false,
        keepModelLoaded: false,
      );
      final text = result?.transcription.text.trim() ?? '';
      return text.isEmpty ? '(No speech detected in this voice note.)' : text;
    } catch (e) {
      return '(Voice note saved, but transcription failed: $e)';
    } finally {
      if (wavFile != null && await wavFile.exists()) {
        try {
          await wavFile.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    }
  }

  TranscriptSegment? segmentAt(List<TranscriptSegment> segments, Duration position) {
    if (segments.isEmpty) return null;
    for (final s in segments) {
      if (position >= s.start && position < s.end) return s;
    }
    if (position >= segments.last.start) return segments.last;
    return segments.first;
  }
}
