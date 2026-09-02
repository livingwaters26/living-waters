# Commute Notes

Offline Android app for listening to scripture (or any MP3) with labeled sessions, scrolling captions, voice/typed notes, and robust capture of context.

Designed for commute (big buttons, driving-friendly) and quiet environments (spa) where you can hush the audio and still follow the text.

## Core Features (from design)

- **Import from folder**: point the app at a directory of MP3s, then tick/check the ones you want to bring into the library
- **Labeled Sessions** per file (e.g. “John 3 – Morning Commute”)
- Pre-generated timed transcript → **scrolling captions**
- **Mute / Hush** audio while captions continue
- **New Note** (big button):
  - Captures exact timestamp
  - Captures the caption text currently on screen
  - Records your voice (kept as short clip) **or** lets you type
- Notes survive abrupt stop / unexpected shutdown
- Tap a note later → jump to that moment + see the original caption context
- Simple local outline + clean export for later AI study (related scripture, etc.)
- Big touch targets for driving

## Project Status (2026-08-17 — Whisper confirmed working, voice notes wired in)

**Working in code:**
- Import MP3s, labeled sessions (auto-named from the filename + date), play/pause/seek/mute
- Resume last position, phone-call pause handling
- Real scripture captions via on-device Whisper (`whisper_ggml`) — confirmed
  working at roughly 4x real-time in release mode
- Voice notes: pausing playback starts recording, tapping again stops it,
  transcribes it with Whisper, and saves it as a Note (typed notes still
  available too) — just wired in, not yet build-tested
- Notes list (tap to jump), export/outline
- Simple JSON storage

See **NEXT_SESSION.md** for exact pick-up steps, device id, and what's next.

## How to run on your machine

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (3.22+ recommended).
2. Clone or copy this `commute_notes` folder.
3. From the project root:

```bash
flutter pub get
flutter run
```

4. Real offline captions use `whisper_ggml`; the model downloads once on first "Generate captions" tap (needs Wi-Fi), then works fully offline.

## Recommended next implementation order

1. Wire Drift database + basic CRUD for AudioFile / Session / Note
2. Integrate `just_audio` (play, pause, seek, position stream, lastPosition save)
3. Real folder picker + MP3 listing + multi-select import (replace placeholder in ImportFolderScreen)
4. Voice note recording (`record` package) with immediate disk write
5. One-time transcript generation service (start with a stub that creates fake timed segments so UI works)
6. Display real captions from transcript
7. On-device STT for spoken notes
8. Export + simple outline
9. Polish big-button UX, tablet layout, recovery logic

## Design decisions locked in

- Android first (phone + tablet)
- Fully offline after initial setup
- Captions from **pre-generated** timed transcript (Option A) – light on resources during use
- Note recorder only listens when you press the button (does not continuously record the speakers)
- Keep short voice clips of spoken notes
- Typing also supported
- Battery not a primary constraint (device usually plugged in)

---

When you open this project in VS Code or Android Studio you already have a runnable UI skeleton with the main screens and the exact interaction model we designed.
