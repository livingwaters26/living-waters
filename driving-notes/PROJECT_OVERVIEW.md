# Commute Notes — Complete Project Overview

**As of:** 2026-08-23 (round 31)
**Read this first if you're picking this project up cold.** For the exact state of in-progress work, read `NEXT_SESSION.md` next — this file is the big picture, that one is the punch list.

---

## 1. What this is

Commute Notes is an offline Android app for listening to scripture (or any MP3 — podcasts, personal recordings, teaching audio) with scrolling captions synced to playback, and a big-button, driving-friendly way to capture voice or typed notes without losing your place. It also has a text-to-speech "Read Scripture Aloud" mode that reads real Bible text with no audio file at all, and a teleprompter for recording your own readings.

Built originally by Grok, iterated on extensively with Claude since. Everything works fully offline once set up — the only network calls are one-time (downloading the Whisper speech-to-text model, fetching Bible text chapters, which then cache to disk) plus one optional opt-in feature (AI-suggested reading emphasis, off by default).

## 2. The physical setup

Three pieces of hardware/software work together:

**The tablet** — Samsung Galaxy Tab S10 (model SM-X520), Android 16, device id `R52YA02836J`. This is where the app actually runs and where you interact with it day to day. Connected to the dev PC via USB (File Transfer/MTP mode + USB debugging) for building and installing new versions.

**The dev PC** — Windows machine at `C:\src`. Has the Flutter SDK (`C:\src\flutter`, version 3.47.0) and the actual project (`C:\src\commute_notes`). This is where new code gets built and pushed to the tablet — there's no way to build/deploy the app from anywhere else.

**The Gateway server** — a separate Ubuntu Server box on the home network (`192.168.42.22`, SSH user `willm`, hostname `gateway`). Its job: automatically convert screen/audio recordings from MP4 to MP3, with the leading silence trimmed, before they ever reach Commute Notes. A systemd service (`mp4-to-mp3-watch.service`) watches a Samba-shared folder (`/srv/share/sound recordings`, mapped as `Z:\sound recordings` on Windows) using `inotifywait`; any `.mp4` dropped in there gets run through `ffmpeg` automatically within a few seconds and the converted `.mp3` lands in a `mp3 converts` subfolder. Full details, including how to tune the silence-trimming threshold, live in `gateway_mp4_to_mp3_pipeline.md` in this package.

**How a recording actually flows, end to end:** a screen recorder on the PC (or wherever) saves an MP4 into `Z:\sound recordings` → the Gateway's watcher notices it, waits 2 seconds to be safe against still-copying files, strips video, trims the front silence, encodes to 192kbps MP3 → the finished MP3 lands in `Z:\sound recordings\mp3 converts` → from there it gets imported into Commute Notes (either copied to the tablet directly, or via whatever transfer method is convenient) → inside the app it becomes an `AudioFile`, gets a session, and can be captioned.

## 3. Tech stack

- **Flutter/Dart** (SDK 3.47.0), targeting Android only.
- **just_audio** — playback engine (play/pause/seek/speed, real time-stretching not pitch-shifted, so slowed playback still sounds like a normal voice).
- **flutter_tts** — on-device text-to-speech for "Read Scripture Aloud" (en-US, adjustable rate).
- **whisper_ggml** (whisper.cpp under the hood) — on-device real speech-to-text for captions and voice-note transcription. "base" English model, ~60-75MB, downloads once over Wi-Fi then works fully offline. Needs 16kHz mono WAV input, so source audio is converted first (`WhisperAudioConvert`).
- **record** — voice note recording (m4a/AAC).
- **share_plus** (pinned to `^12.0.2`, not 13.x — a newer version needs a win32 dependency that conflicts with `file_picker`) — sharing/exporting files and notes.
- **permission_handler** — microphone permission flow, including the "Android won't re-prompt after a denial" workaround (a manual "Open Settings" dialog).
- **path_provider**, **path**, **uuid**, **wakelock_plus** (keeps the screen/CPU awake during long operations — Whisper runs, long recordings), **audio_session** (manages audio focus, needed so pausing to record a voice note doesn't leave TTS silently "playing" nothing).
- Two free, no-key Bible text APIs: `bible-api.com` (KJV/WEB/ASV/BBE/DRA) and `bible.helloao.org` (Berean Standard Bible — the default translation used everywhere). Every chapter fetched is cached to disk, so a book works offline after being read once online.
- One optional cloud call: Anthropic's Messages API (`claude-haiku-4-5`) for the teleprompter's opt-in "Analyze for Emphasis" feature — the only network dependency in the app that isn't a one-time/cacheable fetch, and it's off unless the user pastes in their own API key.

## 4. Data model

Everything is flat JSON files in the app's private documents directory (no SQL database):

- `audio_files.json` — one entry per imported/recorded file: path, title, collection (folder), duration, caption state (`hasWhisperCaptions`, `hasScriptureCaptions`, `activeCaptionKind`), caption sync offset, last TTS chapter/verse if applicable.
- `sessions.json` — a labeled listening session tied to exactly one AudioFile, with a last-played position.
- `notes.json` — voice or typed notes, each tied to a Session (not directly to an AudioFile — the two-hop join, Note → Session → AudioFile, matters for anything cross-file like Today's Notes).
- `collections.json` — folder names for organizing the library.
- `settings.json` — currently just the optional Anthropic API key.
- `transcripts/<audioFileId>.json` — captions for that file. Can hold up to two separate sets at once, `{"whisper": [...], "scripture": [...]}`, so running both Whisper transcription and "Caption with Real Text" on the same file no longer overwrites one with the other.

A Session belongs to exactly one AudioFile — there's no way today for one session to span several files (e.g. one "Revelation" session covering multiple chapter-per-file recordings). This is a known, still-open limitation.

## 5. Core features

**Home screen** — three big colored buttons (Read Scripture / My MP3s / Record a Reading), a small floating "Today's Notes" button, and a "Continue your notes" horizontal strip showing books/files with existing notes, most-recent first.

**My MP3s (library)** — import audio (mp3/m4a/wav/aac/ogg/mp4), organize into folders, search/sort, multi-select delete, bulk share, per-file rename/move/delete/share, a "Captions ready" badge, and delete-empty-folder.

**The MP3 player** — big Stop/Record Note/Play transport buttons, ±15s skip, a Speed knob (real time-stretch, 0.5x-2x), notes list with tap-to-jump. Tapping **CC** offers three ways to get captions on a file (see section 6). Once captions exist, a scrolling caption box shows the current line, synced to playback position.

**Read Scripture Aloud** — pick a translation and book, then a chapter grid (with a "Resume" button if you left off mid-chapter). Reads the real verse text aloud with a synthetic voice (flutter_tts), showing each verse as it's spoken. Has its own Speed knob (voice rate, not the same units as playback speed) and the same pause-to-record-a-note flow as the MP3 player.

**Record a Reading** — a standalone long-form recorder for reading scripture or your own text aloud, with an optional on-screen teleprompter (word-per-minute paced, not pixel-based, so font size and reading speed are independent; punctuation-derived breathing pauses; a focus band that dims text above/below the current line; Practice mode to rehearse without recording). Optional AI "Analyze for Emphasis" suggests bold/pause points — verified against the original text so it can never change the actual words, only add styling.

**Today's Notes** — every note from every book/file, grouped by day then by book, with export (all at once or one note at a time).

## 6. The captioning system, in depth

There are three fundamentally different ways a file gets captions, and it's worth understanding the tradeoffs:

1. **Transcribe Anyway (Whisper)** — real on-device speech-to-text on the actual recording. Works on anything (scripture, podcasts, personal recordings), word-for-word accurate to what was actually said, but slow (roughly 0.28x real time in release mode — a 30-minute file takes ~8-9 minutes) and currently has no cancel button once started (force-close is the only way out).

2. **Caption with Real Text** — for recordings of scripture being read aloud. Keeps the recording's own voice playing, and instead of transcribing, pulls the real Berean Standard Bible text for whichever book/chapters you specify and captions with that — instant, no waiting. The book is guessed from the file's title when possible; if not, you're asked to pick it manually. Timing is an **estimate**: each verse gets a slice of the file's total duration proportional to its word count, laid end to end — not a real per-word sync. As of round 31, you can also tell it how many seconds of silence/intro sit at the front (common on podcast-style clips) so the schedule doesn't start "spending" verses before anyone's actually talking. A "Caption sync" knob lets you nudge the whole estimate forward/backward by a flat number of seconds if it drifts.

3. **Read Scripture Instead** — abandons this recording's audio entirely and switches to the synthetic TTS voice reading the real text from scratch (i.e., jumps into the "Read Scripture Aloud" feature described above). No estimation involved since the TTS voice itself drives what's on screen.

A file can hold BOTH a Whisper transcript and Caption-with-Real-Text captions at once (they're saved into separate slots) — when both exist, two chips let you switch which is showing, and the choice is remembered per file.

One data quirk worth knowing if captions ever look "frozen" on Caption-with-Real-Text: the Berean Standard Bible's source data represents prose books (Matthew, etc.) as plain-string verse text, but poetry books (Psalms, Proverbs, Job, Lamentations, Song of Solomon, and poetic stretches elsewhere) wrap each line as `{"text": "...", "poem": N}` instead. `bible_text_service.dart`'s `_joinHelloAoContent()` handles both shapes as of the fix in this package — if it ever silently drops poetry-book text again, that function is where to look first.

## 7. Dev environment / rebuilding

Always build in release mode for real use — debug mode is dramatically slower for Whisper and can make the UI look frozen during transcription:

```
C:\src\flutter\bin\flutter.bat run --release -d R52YA02836J
```

Requirements: tablet in File Transfer/MTP mode (not Charging only), USB debugging enabled and "Allow" accepted. If `flutter` isn't on PATH, use `cmd /c "C:\src\flutter\bin\flutter.bat ..."`.

Recurring gotchas worth knowing:
- `int.clamp(int, int)` in Dart returns `num`, not `int` — needs an explicit `.toInt()` after, or you get an assignment type error. Comes up repeatedly.
- `DropdownButtonFormField.initialValue` and `ExpansionTile.initiallyExpanded` are only read once at mount — force a rebuild with a `key: ValueKey(...)` tied to whatever should change them.
- Manifest changes (`AndroidManifest.xml`) and launcher icon changes need a full rebuild, not hot reload/restart, to take effect.
- Whisper needs `compileSdk` forced to 36 and `ndkVersion` pinned to `29.0.13113456`.

## 8. Known open items (not yet built)

- **Deeper library hierarchy** (translation → narrator → book, for organizing multiple translations/readers of the same books) — fully designed in `LIBRARY_HIERARCHY_PLAN.md`. The user has signaled they want to pick this back up. Before touching `AudioFile` or `library_screen.dart`, three open questions from the plan doc still need answers: (1) where non-Bible content (Personal Readings/sermons) sits — its own top-level section outside the Bible Translations branch, or folded into the same tree; (2) whether the new tree browser replaces `library_screen.dart` entirely or lives alongside it as a second screen; (3) how much of the tree is expanded by default when the library first opens. Check `NEXT_SESSION.md` for whether these have since been answered.
- **No true cancel button for long Whisper runs** — `whisper_ggml` doesn't expose a way to interrupt one in progress. The real fix would be chunking the audio into 5-10 minute pieces and checking a cancel flag between chunks; not started.
- **Filler-word ("um"/"ah") removal** — blocked on two open questions: whether word-level timestamps are actually available from the Whisper package, and what's realistically available for on-device audio splicing/re-encoding in Flutter on Android (ffmpeg-based plugins have had licensing/maintenance churn). Needs real investigation before it's buildable.
- **Voice-following teleprompter scroll** — full feasibility writeup in `TELEPROMPTER_VOICE_FOLLOW_PLAN.md`. Recommended next step is a small spike testing whether the Tab S10 can run two simultaneous microphone captures, before committing to a real build.
- **Android Auto integration** — a build plan exists (`ANDROID_AUTO_BUILD_PLAN.md`) but nothing has been started.
- **No structured/JSON data export** — only human-readable text export exists today. An "Export All Data" JSON bundle is the recommended next step for the planned integration with a separate study-guide-planner app (see `HANDOFF_STUDY_GUIDE_INTEGRATION.md` for the full data model this would need to expose).
- **A Session can only belong to one AudioFile** — no way to have one session span multiple files. Part of the still-deferred library hierarchy rebuild.

## 9. What's in this package

- `PROJECT_OVERVIEW.md` — this file.
- `NEXT_SESSION.md` — the live, up-to-date pickup point: what's currently pushed but unverified, what to check first next session.
- `gateway_mp4_to_mp3_pipeline.md` — full reference for the Gateway server's auto-conversion pipeline, including how to tune the silence-trim settings.
- `HANDOFF_STUDY_GUIDE_INTEGRATION.md` — data model/schema reference for anyone building an integration that imports Commute Notes' data into another app.
- `LIBRARY_HIERARCHY_PLAN.md` — the agreed-but-not-yet-built deeper folder hierarchy design.
- `TELEPROMPTER_VOICE_FOLLOW_PLAN.md` — feasibility writeup for voice-following teleprompter scroll.
- `ANDROID_AUTO_BUILD_PLAN.md` — plan for Android Auto integration, not started.

## 10. Quick reference

**Rebuild and install on the tablet:**
```
C:\src\flutter\bin\flutter.bat run --release -d R52YA02836J
```

**Check the Gateway pipeline is running:**
```
sudo systemctl status mp4-to-mp3-watch.service
```

**Watch the Gateway pipeline convert a file in real time:**
```
sudo journalctl -u mp4-to-mp3-watch.service -f
```

**After editing the Gateway watcher script:**
```
sudo chmod +x /usr/local/bin/mp4-to-mp3-watch.sh
sudo systemctl restart mp4-to-mp3-watch.service
```
