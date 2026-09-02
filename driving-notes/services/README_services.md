# Services (to be implemented)

## Planned services

### AudioPlayerService
- Wraps `just_audio`
- Exposes position stream, duration, play/pause/seek
- Saves `Session.lastPosition` on pause / dispose / periodic timer
- Handles audio session (speakers, Bluetooth, background)

### TranscriptService
- On first open of an AudioFile (or on demand): run offline Whisper on the MP3
- Produce list of `TranscriptSegment` (start, end, text)
- Save as JSON next to the audio or in app documents
- Mark `AudioFile.transcriptReady = true`

### NoteRecorderService
- When user starts note:
  1. Capture current position + current caption text immediately
  2. Start `record` package → write .m4a/.wav to disk right away (crash safety)
  3. On stop: finalize file, run on-device STT on the short clip, create `Note`
- Also supports pure typed notes (no voice clip)

### DatabaseService (Drift)
- Tables: audio_files, sessions, notes
- Simple recovery query for `isComplete = false` notes on app start

### ExportService
- Session → Markdown / plain text / JSON with timestamps + captions + notes
- Ready to paste into Grok for related-scripture insight and richer outline

### ImportFolderService
- Let user choose a directory (persist last used path if desired)
- List *.mp3 (and other audio) files with size
- Multi-select via checkboxes
- Create AudioFile records for the selected paths
