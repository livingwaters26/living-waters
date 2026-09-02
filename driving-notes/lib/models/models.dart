// Core data models for Driving Notes

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Represents an imported MP3 (or other audio) file.
class AudioFile {
  final String id;
  final String path;
  final String title;
  final Duration duration;
  final DateTime dateAdded;
  final String? transcriptPath; // Path to the generated timed transcript JSON/file
  final bool transcriptReady;
  // Which "folder" this belongs to in the library (e.g. "ESV Dramatized",
  // "Personal Readings"). Files imported before this existed default to
  // "Uncategorized" so old libraries still load fine. Still used as-is for
  // non-Bible content (Personal Readings/sermons/teaching); for Bible
  // content, translation/narrator below replace its organizing role - see
  // LIBRARY_HIERARCHY_PLAN.md.
  final String collection;
  // Real hierarchy fields (added for the translation -> narrator -> book
  // library tree), separate from the flat `collection` tag above. Empty
  // string means "not tagged" - a file with an empty translation is treated
  // as non-Bible/personal content and keeps using `collection` to group it,
  // exactly like before this existed. `book` is deliberately NOT a stored
  // field - it's derived from the title via BibleTextService.findBookId()
  // the same way it already was for captions, so there's one source of
  // truth for "what book is this" instead of two that could disagree.
  final String translation;
  final String narrator;
  // Where you left off in a "Read Scripture" (TTS) book - not meaningful
  // for a real MP3/recording. Tracked on the AudioFile itself (not the
  // Session) since "where you are in the book" is a property of the book,
  // not of any one sitting - reopening it tomorrow under a brand new
  // Session should still offer to resume here. 0 means "no progress yet".
  final int lastChapter;
  final int lastVerse;
  // A file can now hold captions from BOTH methods at once instead of one
  // overwriting the other - hasWhisperCaptions/hasScriptureCaptions track
  // which ones actually exist, and activeCaptionKind ('whisper' or
  // 'scripture') is which one the player is currently showing/looking up.
  final bool hasWhisperCaptions;
  final bool hasScriptureCaptions;
  final String activeCaptionKind;
  // A fixed nudge (in milliseconds) applied to real playback position before
  // looking up which ESTIMATED ("Caption with Real Text" / scripture-synced)
  // caption to show - 0 is unshifted. Positive catches captions up (shows
  // later text sooner, for when they're lagging behind the narration);
  // negative holds them back (for when they're racing ahead). A flat
  // second-for-second shift, not a multiplier - deliberately simple so a
  // "+10s" reading always means exactly 10 seconds everywhere in the file,
  // instead of a scale factor whose effect silently grows the further into
  // the file you are (confusing to dial in - see round 30 follow-up).
  // Only meaningful when activeCaptionKind is 'scripture' - real Whisper
  // timestamps come from actually hearing the audio and don't drift the
  // way an estimate can.
  final int captionSyncOffsetMs;

  AudioFile({
    String? id,
    required this.path,
    required this.title,
    required this.duration,
    DateTime? dateAdded,
    this.transcriptPath,
    this.transcriptReady = false,
    this.collection = 'Uncategorized',
    this.translation = '',
    this.narrator = '',
    this.lastChapter = 0,
    this.lastVerse = 0,
    this.hasWhisperCaptions = false,
    this.hasScriptureCaptions = false,
    this.activeCaptionKind = 'whisper',
    this.captionSyncOffsetMs = 0,
  })  : id = id ?? _uuid.v4(),
        dateAdded = dateAdded ?? DateTime.now();

  AudioFile copyWith({
    String? path,
    String? title,
    Duration? duration,
    String? transcriptPath,
    bool? transcriptReady,
    String? collection,
    String? translation,
    String? narrator,
    int? lastChapter,
    int? lastVerse,
    bool? hasWhisperCaptions,
    bool? hasScriptureCaptions,
    String? activeCaptionKind,
    int? captionSyncOffsetMs,
  }) {
    return AudioFile(
      id: id,
      path: path ?? this.path,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      dateAdded: dateAdded,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      transcriptReady: transcriptReady ?? this.transcriptReady,
      collection: collection ?? this.collection,
      translation: translation ?? this.translation,
      narrator: narrator ?? this.narrator,
      lastChapter: lastChapter ?? this.lastChapter,
      lastVerse: lastVerse ?? this.lastVerse,
      hasWhisperCaptions: hasWhisperCaptions ?? this.hasWhisperCaptions,
      hasScriptureCaptions: hasScriptureCaptions ?? this.hasScriptureCaptions,
      activeCaptionKind: activeCaptionKind ?? this.activeCaptionKind,
      captionSyncOffsetMs: captionSyncOffsetMs ?? this.captionSyncOffsetMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'title': title,
        'durationMs': duration.inMilliseconds,
        'dateAdded': dateAdded.toIso8601String(),
        'transcriptPath': transcriptPath,
        'transcriptReady': transcriptReady ? 1 : 0,
        'collection': collection,
        'lastChapter': lastChapter,
        'lastVerse': lastVerse,
        'hasWhisperCaptions': hasWhisperCaptions ? 1 : 0,
        'hasScriptureCaptions': hasScriptureCaptions ? 1 : 0,
        'activeCaptionKind': activeCaptionKind,
        'captionSyncOffsetMs': captionSyncOffsetMs,
        'translation': translation,
        'narrator': narrator,
      };

  factory AudioFile.fromMap(Map<String, dynamic> map) {
    final ready = (map['transcriptReady'] as int?) == 1;
    // Back-compat with libraries saved before dual captions existed: the
    // old single 'transcriptIsEstimated' flag said which kind that one
    // saved transcript was. If the newer keys aren't present yet, derive
    // them from that instead of losing track of what's actually saved.
    final legacyEstimated = (map['transcriptIsEstimated'] as int?) == 1;
    final hasWhisper = map.containsKey('hasWhisperCaptions')
        ? (map['hasWhisperCaptions'] as int?) == 1
        : (ready && !legacyEstimated);
    final hasScripture = map.containsKey('hasScriptureCaptions')
        ? (map['hasScriptureCaptions'] as int?) == 1
        : (ready && legacyEstimated);
    return AudioFile(
      id: map['id'] as String,
      path: map['path'] as String,
      title: map['title'] as String,
      duration: Duration(milliseconds: map['durationMs'] as int),
      dateAdded: DateTime.parse(map['dateAdded'] as String),
      transcriptPath: map['transcriptPath'] as String?,
      transcriptReady: ready || hasWhisper || hasScripture,
      collection: map['collection'] as String? ?? 'Uncategorized',
      translation: map['translation'] as String? ?? '',
      narrator: map['narrator'] as String? ?? '',
      lastChapter: map['lastChapter'] as int? ?? 0,
      lastVerse: map['lastVerse'] as int? ?? 0,
      hasWhisperCaptions: hasWhisper,
      hasScriptureCaptions: hasScripture,
      activeCaptionKind: map['activeCaptionKind'] as String? ?? (legacyEstimated ? 'scripture' : 'whisper'),
      // Old libraries had a multiplicative 'captionSyncScale' instead - that
      // mechanism is gone (replaced this round), and there's no meaningful
      // way to convert a scale into a flat offset, so it just resets to 0
      // (unshifted) rather than carrying over a stale/confusing value.
      captionSyncOffsetMs: (map['captionSyncOffsetMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A labeled study / listening session on one AudioFile.
class Session {
  final String id;
  final String audioFileId;
  final String label;
  final Duration lastPosition;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Nested folder under this audio file, e.g. "Week 1/Morning". Empty = root.
  final String folderPath;

  Session({
    String? id,
    required this.audioFileId,
    required this.label,
    this.lastPosition = Duration.zero,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.folderPath = '',
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Session copyWith({
    String? label,
    Duration? lastPosition,
    DateTime? updatedAt,
    String? folderPath,
  }) {
    return Session(
      id: id,
      audioFileId: audioFileId,
      label: label ?? this.label,
      lastPosition: lastPosition ?? this.lastPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      folderPath: folderPath ?? this.folderPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'audioFileId': audioFileId,
        'label': label,
        'lastPositionMs': lastPosition.inMilliseconds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'folderPath': folderPath,
      };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
        id: map['id'] as String,
        audioFileId: map['audioFileId'] as String,
        label: map['label'] as String,
        lastPosition: Duration(milliseconds: map['lastPositionMs'] as int),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        folderPath: map['folderPath'] as String? ?? '',
      );
}

/// A single note belonging to a Session.
class Note {
  final String id;
  final String sessionId;
  final Duration timestamp; // Position in the audio when note was created
  final String captionContext; // Text that was on screen (from transcript)
  final String text; // User's spoken or typed note
  final String? voiceClipPath; // Optional short recording of the user
  final DateTime createdAt;
  final bool isComplete; // False if interrupted / needs recovery

  Note({
    String? id,
    required this.sessionId,
    required this.timestamp,
    required this.captionContext,
    required this.text,
    this.voiceClipPath,
    DateTime? createdAt,
    this.isComplete = true,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Note copyWith({
    String? captionContext,
    String? text,
    String? voiceClipPath,
    bool? isComplete,
  }) {
    return Note(
      id: id,
      sessionId: sessionId,
      timestamp: timestamp,
      captionContext: captionContext ?? this.captionContext,
      text: text ?? this.text,
      voiceClipPath: voiceClipPath ?? this.voiceClipPath,
      createdAt: createdAt,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'timestampMs': timestamp.inMilliseconds,
        'captionContext': captionContext,
        'text': text,
        'voiceClipPath': voiceClipPath,
        'createdAt': createdAt.toIso8601String(),
        'isComplete': isComplete ? 1 : 0,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        sessionId: map['sessionId'] as String,
        timestamp: Duration(milliseconds: map['timestampMs'] as int),
        captionContext: map['captionContext'] as String? ?? '',
        text: map['text'] as String? ?? '',
        voiceClipPath: map['voiceClipPath'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        isComplete: (map['isComplete'] as int? ?? 1) == 1,
      );
}

/// One segment of a timed transcript (for scrolling captions).
class TranscriptSegment {
  final Duration start;
  final Duration end;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      TranscriptSegment(
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
        text: json['text'] as String,
      );
}

/// Holds both possible caption sets for one AudioFile at once - a real
/// Whisper transcript and/or estimated scripture-synced captions. Either
/// side can be null if that method hasn't been run yet. See
/// TranscriptService.loadBundle/saveKind.
class TranscriptBundle {
  final List<TranscriptSegment>? whisper;
  final List<TranscriptSegment>? scripture;

  const TranscriptBundle({this.whisper, this.scripture});
}
