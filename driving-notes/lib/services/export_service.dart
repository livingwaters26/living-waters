import '../models/models.dart';

/// Pairs a Note with which AudioFile it belongs to - a Note on its own
/// doesn't carry a book/file title, so anywhere notes from multiple
/// different books/files are shown or exported together (the Today's
/// Notes screen) needs this instead of a bare Note.
class NoteWithSource {
  final Note note;
  final String audioFileId;
  final String audioTitle;

  const NoteWithSource({
    required this.note,
    required this.audioFileId,
    required this.audioTitle,
  });
}

/// Builds a clean text / Markdown export of a Session's notes - for
/// copying into any app you want, or saving as a small standalone text
/// file.
class ExportService {
  /// A filesystem-safe name to save a session's notes under, e.g.
  /// "Daniel_8_17_2026_notes.txt" - strips anything that isn't a letter,
  /// number, space, or dash, and collapses spaces to underscores.
  String safeFileName(String sessionLabel) {
    final cleaned = sessionLabel.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').trim();
    final withUnderscores = cleaned.replaceAll(RegExp(r'\s+'), '_');
    final name = withUnderscores.isEmpty ? 'notes' : withUnderscores;
    return '${name}_notes.txt';
  }

  /// A filesystem-safe name to share/save an audio file under, using its
  /// library title (e.g. "Daniel Reading" -> "Daniel_Reading.m4a") and
  /// keeping whatever extension the file actually has - .m4a for an
  /// in-app recording, or the original extension for an imported MP3.
  String safeAudioFileName(String title, String sourcePath) {
    final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').trim();
    final withUnderscores = cleaned.replaceAll(RegExp(r'\s+'), '_');
    final name = withUnderscores.isEmpty ? 'audio' : withUnderscores;
    final dot = sourcePath.lastIndexOf('.');
    final ext = (dot >= 0 && dot < sourcePath.length - 1) ? sourcePath.substring(dot + 1) : 'm4a';
    return '$name.$ext';
  }

  /// Plain text that is easy to paste into a chat.
  String toPlainText({
    required String sessionLabel,
    required String audioTitle,
    required List<Note> notes,
    String? sourceDescription,
  }) {
    final buf = StringBuffer();
    buf.writeln('Session: $sessionLabel');
    buf.writeln('Audio: $audioTitle');
    if (sourceDescription != null && sourceDescription.isNotEmpty) {
      buf.writeln('Source: $sourceDescription');
    }
    buf.writeln('');
    buf.writeln('Notes (oldest first):');
    buf.writeln('');

    final ordered = List<Note>.from(notes)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final n in ordered) {
      buf.writeln('[${_fmt(n.timestamp)}]');
      if (n.captionContext.isNotEmpty) {
        buf.writeln('Context: ${n.captionContext}');
      }
      buf.writeln('Note: ${n.text}');
      buf.writeln('');
    }

    return buf.toString().trimRight();
  }

  /// Simple local outline (no heavy AI needed on the phone).
  String toOutline({
    required String sessionLabel,
    required String audioTitle,
    required List<Note> notes,
  }) {
    final buf = StringBuffer();
    buf.writeln('# Outline: $sessionLabel');
    buf.writeln('Audio: $audioTitle');
    buf.writeln('');

    final ordered = List<Note>.from(notes)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (ordered.isEmpty) {
      buf.writeln('No notes in this session yet.');
      return buf.toString();
    }

    buf.writeln('## Questions & notes in order');
    buf.writeln('');
    for (var i = 0; i < ordered.length; i++) {
      final n = ordered[i];
      buf.writeln('${i + 1}. [${_fmt(n.timestamp)}] ${n.text}');
      if (n.captionContext.isNotEmpty) {
        buf.writeln('   Context: ${n.captionContext}');
      }
      buf.writeln('');
    }

    buf.writeln('## Quick list of timestamps');
    for (final n in ordered) {
      buf.writeln('- ${_fmt(n.timestamp)}');
    }

    return buf.toString().trimRight();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _dateTimeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:$m $ampm';
  }

  /// A short human-readable label for where a note falls - a real
  /// "chapter:verse" reference when the caption looks like real scripture
  /// text (true for anything captioned from real scripture text - Read
  /// Scripture's live captions, or the "Caption with Real Text" feature),
  /// otherwise how far into the recording the note was taken.
  String _referenceLabel(Note note) {
    final match = RegExp(r'^(\d+:\d+)').firstMatch(note.captionContext.trim());
    if (match != null) return match.group(1)!;
    return '${_fmt(note.timestamp)} in';
  }

  /// Same reference, but filesystem-safe (colons aren't valid in Windows
  /// file names, which matters since these files often get shared/saved
  /// onto a PC) - "1:9" becomes "1-9" instead of being silently dropped.
  String _referenceForFileName(Note note) {
    final match = RegExp(r'^(\d+:\d+)').firstMatch(note.captionContext.trim());
    final raw = match != null ? match.group(1)! : _fmt(note.timestamp);
    return raw.replaceAll(':', '-');
  }

  /// A filesystem-safe name for exporting one note on its own - built from
  /// the same "book/title + chapter:verse (or timestamp) + when it was
  /// taken" pattern used everywhere else in the app (session labels, audio
  /// file sharing), so an exported note's file name lines up with how
  /// everything else here is already named.
  String safeNoteFileName(NoteWithSource n) {
    final createdAt = n.note.createdAt;
    final h = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final m = createdAt.minute.toString().padLeft(2, '0');
    final ampm = createdAt.hour >= 12 ? 'PM' : 'AM';
    final raw = '${n.audioTitle} ${_referenceForFileName(n.note)} '
        '${createdAt.month}-${createdAt.day}-${createdAt.year} $h-$m$ampm';
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').trim();
    final withUnderscores = cleaned.replaceAll(RegExp(r'\s+'), '_');
    final name = withUnderscores.isEmpty ? 'note' : withUnderscores;
    return '$name.txt';
  }

  /// Content for exporting a single note as its own small text file.
  String singleNoteText(NoteWithSource n) {
    final note = n.note;
    final buf = StringBuffer();
    buf.writeln(n.audioTitle);
    buf.writeln('${_referenceLabel(note)}  •  ${_dateTimeLabel(note.createdAt)}');
    buf.writeln('');
    if (note.captionContext.isNotEmpty) {
      buf.writeln('Context: ${note.captionContext}');
      buf.writeln('');
    }
    buf.writeln(note.text);
    return buf.toString().trimRight();
  }

  /// A simple, consistently-named file name for the combined "export
  /// everything currently shown" file on the Today's Notes screen.
  String safeAllNotesFileName() {
    final now = DateTime.now();
    return 'All_Notes_${now.month}-${now.day}-${now.year}.txt';
  }

  /// Combined export of every note passed in, grouped by day (most recent
  /// first) - used by "Export All" on the Today's Notes screen so
  /// everything currently on screen lands in one shareable file instead of
  /// one at a time.
  String allNotesDigest(List<NoteWithSource> entries) {
    final buf = StringBuffer();
    buf.writeln('Driving Notes - All Notes');
    buf.writeln('Exported ${_dateTimeLabel(DateTime.now())}');
    buf.writeln('');

    final byDay = <DateTime, List<NoteWithSource>>{};
    for (final e in entries) {
      final d = e.note.createdAt;
      final day = DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(day, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final day in days) {
      buf.writeln('== ${day.month}/${day.day}/${day.year} ==');
      buf.writeln('');
      for (final e in byDay[day]!) {
        buf.writeln('${e.audioTitle}  -  ${_referenceLabel(e.note)}  •  ${_dateTimeLabel(e.note.createdAt)}');
        if (e.note.captionContext.isNotEmpty) {
          buf.writeln('Context: ${e.note.captionContext}');
        }
        buf.writeln(e.note.text);
        buf.writeln('');
      }
    }

    return buf.toString().trimRight();
  }
}
