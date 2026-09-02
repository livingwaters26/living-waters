# Commute Notes — Data Model & Export Handoff

**Written:** 2026-08-18
**Purpose:** technical reference for building an integration that imports Commute Notes' notes into a separate study-guide planner app. Read this before touching export/import code for that integration — it documents the exact schema and storage as it exists in the codebase today, not a proposed redesign.

## 1. What this app is

Commute Notes is an offline Android app (Flutter) for listening to scripture or any MP3, taking timestamped voice/typed notes while listening, and reading scripture aloud via on-device text-to-speech. Full project background is in `NEXT_SESSION.md` and project memory — this file only covers the data side.

## 2. Where the data actually lives

All data is stored as flat JSON files in the app's **private** Android app-documents directory (`getApplicationDocumentsDirectory()`), typically `/data/user/0/<applicationId>/app_flutter/` on-device. This is **not** reachable via USB/MTP file browsing or a normal file manager (Android scoped storage) — only the app itself, or ADB with root/`run-as`, can read it directly. Practically, the only way to get data out today is through the app's own share/export UI (see §5).

Files, all in that private documents directory:
- `audio_files.json` — JSON array of AudioFile records
- `sessions.json` — JSON array of Session records
- `notes.json` — JSON array of Note records
- `collections.json` — JSON array of plain strings (collection/folder names)
- `transcripts/<audioFileId>.json` — one file per audio file that has captions generated, JSON array of TranscriptSegment
- `recordings/<uuid>.m4a` — audio for "Record a Reading" long-form recordings
- `voice_notes/<uuid>.m4a` — audio clips for short pause-to-record voice notes (before they're transcribed into `Note.text`)
- `imported_audio/` — copies of MP3s imported via the file picker
- `bible_cache/` — cached Bible chapter JSON (not relevant to notes export)

All storage/serialization code lives in `lib/services/simple_storage.dart`; the model classes with `toMap()`/`fromMap()` are in `lib/models/models.dart`.

## 3. Data model / JSON schema

### AudioFile — one record per MP3, recording, or "Read Scripture" book entry

```json
{
  "id": "uuid",
  "path": "string",
  "title": "string",
  "durationMs": 0,
  "dateAdded": "ISO8601 string",
  "transcriptPath": "string or null",
  "transcriptReady": 0,
  "collection": "string",
  "lastChapter": 0,
  "lastVerse": 0
}
```

- `path` is a real file path for MP3s/recordings, OR a synthetic string like `"tts:bsb:JHN"` (`tts:<translation>:<bookId>`) for a Read Scripture entry — those have **no real audio file behind them**. Filter these out (`path.startsWith('tts:')`) if the target planner only cares about real audio + notes; keep them in if it should also surface scripture-reading progress.
- `transcriptReady` is stored as an int (0/1), not a JSON boolean — normalize on import.
- `collection` defaults to `"Uncategorized"`; it's a single flat folder name, no nesting.
- `lastChapter`/`lastVerse` are only meaningful for `tts:` entries (where you left off reading that book); 0 means no progress.

### Session — a labeled sitting/listen-through of one AudioFile (many Sessions per AudioFile)

```json
{
  "id": "uuid",
  "audioFileId": "uuid — foreign key to AudioFile.id",
  "label": "string, e.g. \"John 3 – 8/18/2026 4:12 PM\"",
  "lastPositionMs": 0,
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

### Note — the actual study content (many Notes per Session)

```json
{
  "id": "uuid",
  "sessionId": "uuid — foreign key to Session.id",
  "timestampMs": 0,
  "captionContext": "string — the caption/verse text on screen when the note was taken",
  "text": "string — the note itself (typed, or transcribed from a spoken clip)",
  "voiceClipPath": "string or null — path to the recorded clip, if this note was spoken",
  "createdAt": "ISO8601",
  "isComplete": 1
}
```

This is almost certainly the entity a study-guide planner cares about most: `text` is the note content, `captionContext` is the source passage it was attached to, `timestampMs` is where in the audio it happened.

**Important:** Note has no direct `audioFileId` — you must join `Note.sessionId → Session.id → Session.audioFileId → AudioFile` to know which book/recording a note belongs to.

### TranscriptSegment — per-file caption timing (only exists if captions were generated for that file)

```json
{ "startMs": 0, "endMs": 0, "text": "string" }
```

## 4. Reconstructing a study-guide-friendly shape

```
AudioFile (book/recording)
  └─ 1:many Session (a sitting/listen)
       └─ 1:many Note (the actual content)
```

To get "book title + note text + context + when it was taken," join `notes.json` → `sessions.json` (on `sessionId`) → `audio_files.json` (on `audioFileId`). `isComplete: 0` marks a note that was interrupted mid-save (crash/battery/phone-call edge case) — the app self-heals these back to `1` on next launch (`findIncompleteNotes()` in `simple_storage.dart`), so in practice this should always be `1` by the time you'd read the file, but worth defensively skipping `0` records if you ever see one.

## 5. What already exists for getting data OUT of the app today

- **Per-session, human-readable only** — "Copy Notes" (plain text to clipboard) and "Save as Text File" (`.txt` via the Android share sheet), built by `ExportService.toPlainText()` / `toOutline()` in `lib/services/export_service.dart`. Not structured/machine-parseable, and only one session at a time.
- **Per-file audio sharing** (added this session) — shares the raw `.m4a`/`.mp3` file itself via the share sheet, not notes.
- **Nothing today exports the full library, or exports as structured JSON.** This is the actual gap for a real integration.

## 6. Recommended next build step for a real integration

Add an **"Export All Data"** feature to Commute Notes itself:
- One button (e.g. on a Settings screen, or the Home screen) that gathers every AudioFile + its Sessions + their Notes (and optionally transcripts) into a single nested JSON document, then hands it to the same `share_plus` flow already proven three times this session (notes-as-text, audio-file sharing) — so it goes out via the normal Android share sheet (email to yourself, save to Drive, AirDrop-equivalent, etc.). No new plumbing needed, no ADB/root required.
- Suggested export shape (a superset of the raw storage format, denormalized for convenience):

```json
{
  "exportedAt": "ISO8601",
  "books": [
    {
      "audioFile": { "...AudioFile fields..." },
      "sessions": [
        {
          "session": { "...Session fields..." },
          "notes": [ { "...Note fields..." } ]
        }
      ]
    }
  ]
}
```

This can be built entirely from the existing `SimpleStorage.loadAudioFiles()` / `loadSessions()` / `loadNotes()` calls plus one JSON-encode — no new storage format, just a new read-and-bundle step.

## 7. Open questions for whoever picks this up next

- **What format does the target study-guide planner actually expect?** Its own JSON schema, CSV, Markdown, something else? Once known, either shape the export above to match directly, or keep this as a generic export and write a small converter on the planner's side.
- **Does the planner need the audio itself, or text only?** If it wants audio too, the export would need to either bundle `.m4a` files (larger payload, multiple share-sheet items) or just reference paths (only useful if both apps run on the same device/have shared storage access).
- **This data is 100% local — no cloud sync, no server.** Everything lives only on the Galaxy Tab S10 unless explicitly shared out. Any integration has to either run on that same device, or move data off it manually via the share sheet first (there's no API/network endpoint to poll).
- **Multiple `tts:` (Read Scripture) entries vs. real audio files** — decide up front whether the planner wants scripture-reading notes mixed in with real MP3/recording notes, or filtered to one or the other; the `path` prefix check (§3) is how to tell them apart.
