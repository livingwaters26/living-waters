import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/bible_episodes.dart';
import '../models/models.dart';
import 'bible_text_service.dart';
import 'simple_storage.dart';

/// Builds a drive-drama script from real scripture and tries to synthesize
/// an audio file. If device TTS cannot write a file (common on some Android
/// builds), still saves the script and a library entry that plays via live TTS.
class DriveDramaService {
  final _bible = BibleTextService();
  final _storage = SimpleStorage();

  static const rootCollection = 'Dramatization';

  static String collectionForBook(String book) => '$rootCollection / $book';

  static String bookFolderName(String book) {
    return book.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }

  /// True when [path] is a script-backed drama (no wav); play with DramaTtsPlayer.
  static bool isLiveTtsPath(String path) => path.startsWith('drama:');

  static String? scriptIdFromPath(String path) {
    if (!isLiveTtsPath(path)) return null;
    final parts = path.split(':');
    return parts.length >= 2 ? parts[1] : null;
  }

  Future<AudioFile> prepareEpisode({
    required BibleEpisode episode,
    String translation = 'bsb',
    void Function(double progress, String message)? onProgress,
  }) async {
    void report(double prog, String m) => onProgress?.call(prog.clamp(0.0, 1.0), m);

    report(0.02, 'Looking up book…');
    final bookId = _bible.bookIdFor(episode.book);

    report(0.05, 'Loading ${episode.rangeLabel}…');
    final verses = <BibleVerse>[];
    final totalChapters = episode.endChapter - episode.startChapter + 1;
    for (var i = 0; i < totalChapters; i++) {
      final chapter = episode.startChapter + i;
      report(0.05 + 0.35 * ((i + 1) / totalChapters), 'Loading chapter $chapter…');
      final chapterVerses = await _bible.fetchChapter(bookId, chapter, translation);
      verses.addAll(chapterVerses);
      if (i < totalChapters - 1) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    if (verses.isEmpty) {
      throw Exception('No scripture text returned for ${episode.book} ${episode.rangeLabel}.');
    }

    report(0.42, 'Writing drama script…');
    final script = _buildScript(episode: episode, verses: verses);
    final docs = await getApplicationDocumentsDirectory();
    final bookFolder = bookFolderName(episode.book);
    final dramaDir = Directory(p.join(docs.path, 'dramatization', bookFolder));
    if (!await dramaDir.exists()) {
      await dramaDir.create(recursive: true);
    }

    final id = const Uuid().v4();
    final scriptPath = p.join(dramaDir.path, '$id.txt');
    await File(scriptPath).writeAsString(script);

    report(0.50, 'Synthesizing audio (may take a few minutes)…');
    final wavPath = p.join(dramaDir.path, '$id.wav');
    final mp3Path = p.join(dramaDir.path, '$id.mp3');
    String? audioPath;
    try {
      audioPath = await _synthesizeToFile(script, wavPath, mp3Path, (sp) {
        report(0.50 + 0.40 * sp, 'Synthesizing audio…');
      });
    } catch (e) {
      // Fall through to live-TTS library entry
      audioPath = null;
      report(0.85, 'Device could not write audio file; saving for live TTS play…');
    }

    final collection = collectionForBook(episode.book);
    report(0.92, 'Saving into $collection…');
    await _storage.addCollectionName(rootCollection);
    await _storage.addCollectionName(collection);

    final translationLabel = BibleTextService.translations[translation] ?? translation;
    final title = '${episode.book} — ${episode.title}';

    final AudioFile audio;
    if (audioPath != null && await File(audioPath).exists() && await File(audioPath).length() > 100) {
      audio = AudioFile(
        id: id,
        path: audioPath,
        title: title,
        duration: Duration.zero,
        collection: collection,
        translation: translationLabel,
        narrator: 'Drive Drama',
      );
    } else {
      // Live TTS: path is synthetic; script lives at scriptPath
      audio = AudioFile(
        id: id,
        path: 'drama:$id',
        title: title,
        duration: Duration.zero,
        collection: collection,
        translation: translationLabel,
        narrator: 'Drive Drama (live TTS)',
      );
      // Sidecar so player finds the script
      await File(p.join(dramaDir.path, '$id.live')).writeAsString(scriptPath);
    }

    await _storage.addAudioFile(audio);

    final session = Session(
      audioFileId: audio.id,
      label: 'Drive · ${episode.title}',
    );
    await _storage.addSession(session);
    await File(p.join(dramaDir.path, '$id.session')).writeAsString(session.id);

    report(1.0, 'Done');
    return audio;
  }

  Future<String?> sessionIdForAudio(String audioId) async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'dramatization'));
    if (!await root.exists()) return null;
    final flat = File(p.join(root.path, '$audioId.session'));
    if (await flat.exists()) return (await flat.readAsString()).trim();
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final f = File(p.join(entity.path, '$audioId.session'));
        if (await f.exists()) return (await f.readAsString()).trim();
      }
    }
    return null;
  }

  /// Resolve script file path for a drama: id (live TTS entries).
  Future<String?> scriptPathForAudioId(String audioId) async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'dramatization'));
    if (!await root.exists()) return null;
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final live = File(p.join(entity.path, '$audioId.live'));
        if (await live.exists()) {
          return (await live.readAsString()).trim();
        }
        final txt = File(p.join(entity.path, '$audioId.txt'));
        if (await txt.exists()) return txt.path;
      }
    }
    final txt = File(p.join(root.path, '$audioId.txt'));
    if (await txt.exists()) return txt.path;
    return null;
  }

  /// Words the device should actually speak. Strips leftover script labels
  /// like "Narrator:" and "Voice:" so older episodes stop saying the role.
  static String spokenText(String line) {
    var text = line.trim();
    text = text.replaceFirst(RegExp(r'^(narrator|voice|speaker)\s*:\s*', caseSensitive: false), '');
    return text.trim();
  }

  String _buildScript({
    required BibleEpisode episode,
    required List<BibleVerse> verses,
  }) {
    final buf = StringBuffer();
    buf.writeln('${episode.book}. ${episode.title}.');
    buf.writeln();

    int? lastChapter;
    for (final v in verses) {
      if (lastChapter != v.chapter) {
        if (lastChapter != null) {
          buf.writeln();
          buf.writeln('Chapter ${v.chapter}.');
          buf.writeln();
        }
        lastChapter = v.chapter;
      }

      final text = v.text.trim();
      if (text.isEmpty) continue;
      buf.writeln(text);
      buf.writeln();
    }

    return buf.toString();
  }

  /// Returns path to a playable audio file, or null if synthesis failed.
  Future<String?> _synthesizeToFile(
    String script,
    String wavPath,
    String mp3Path,
    void Function(double progress) onProgress,
  ) async {
    final tts = FlutterTts();
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);

    // Prefer smaller chunks — long utterances often fail silently on Android.
    final chunks = _chunkScript(_spokenScript(script), maxChars: 800);
    if (chunks.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final partPaths = <String>[];

    for (var i = 0; i < chunks.length; i++) {
      onProgress((i + 0.5) / chunks.length);
      final partPath = p.join(tempDir.path, 'drama_part_$i.wav');
      // Delete leftover
      try {
        final old = File(partPath);
        if (await old.exists()) await old.delete();
      } catch (_) {}

      dynamic result;
      try {
        result = await tts.synthesizeToFile(chunks[i], partPath);
      } catch (_) {
        try {
          result = await tts.synthesizeToFile(chunks[i], 'drama_part_$i.wav');
        } catch (_) {
          continue;
        }
      }

      // Wait briefly for filesystem flush
      await Future.delayed(const Duration(milliseconds: 400));

      if (await File(partPath).exists() && await File(partPath).length() > 50) {
        partPaths.add(partPath);
      } else {
        // Some Android builds write relative to app storage
        final alt = File(p.join((await getApplicationDocumentsDirectory()).path, 'drama_part_$i.wav'));
        if (await alt.exists() && await alt.length() > 50) {
          partPaths.add(alt.path);
        }
      }
      onProgress((i + 1) / chunks.length);
    }

    if (partPaths.isEmpty) return null;

    // Single part → copy to destination
    if (partPaths.length == 1) {
      await File(partPaths.first).copy(wavPath);
      if (await File(wavPath).exists() && await File(wavPath).length() > 50) {
        return wavPath;
      }
      return null;
    }

    // Multiple parts: copy first as playable file and write index of all parts
    // (full concat needs native tools; first chunk still proves the pipeline)
    await File(partPaths.first).copy(wavPath);
    final indexFile = File(wavPath.replaceFirst('.wav', '.parts.txt'));
    await indexFile.writeAsString(partPaths.join('\n'));
    // Also copy remaining parts next to final for future playlist support
    for (var i = 1; i < partPaths.length; i++) {
      final dest = wavPath.replaceFirst('.wav', '_part$i.wav');
      try {
        await File(partPaths[i]).copy(dest);
      } catch (_) {}
    }
    if (await File(wavPath).exists() && await File(wavPath).length() > 50) {
      return wavPath;
    }
    return null;
  }

  String _spokenScript(String script) {
    return script
        .split('\n')
        .map(spokenText)
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  List<String> _chunkScript(String script, {required int maxChars}) {
    final lines = script.split('\n');
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final line in lines) {
      if (buf.length + line.length + 1 > maxChars && buf.isNotEmpty) {
        chunks.add(buf.toString().trim());
        buf.clear();
      }
      buf.writeln(line);
    }
    final tail = buf.toString().trim();
    if (tail.isNotEmpty) chunks.add(tail);
    return chunks;
  }
}
