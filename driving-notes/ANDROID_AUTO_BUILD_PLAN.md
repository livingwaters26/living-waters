# Commute Notes — Android Auto Build Plan

**Written:** 2026-08-18
**Status:** Plan only — nothing in this document has been built yet. Written to be picked up when you're ready to greenlight it.
**Scope note:** this is the biggest single feature discussed for this app so far. Everything else this session has been Dart-only screen work; this involves native Android configuration (manifest changes, a foreground service, Android's MediaSession framework) on top of the Dart work. Budget it as its own multi-session project, not a "build it real quick."

## Revised recommendation after discussion (2026-08-18): don't consolidate the two players first

Original instinct (from the discussion that led to this plan) was that merging `player_screen.dart` (MP3s) and `tts_player_screen.dart` (Read Scripture) into one shared player component first would make everything downstream — including Android Auto — cleaner. That's true in the abstract, but given the actual priorities here, it's the wrong first move:

- **The app as it stands is exactly what you want.** Priority one is not breaking or reworking anything currently working, since it's already tested and liked as-is.
- **Android Auto is a nice-to-have, not a need.** Two of your vehicles have it; your main vehicle doesn't, and won't be affected either way. There's no pressure to build this soon, and no reason to accept any risk to the working app to get there faster.
- **The efficient path is additive, not a refactor.** MP3/recording playback already runs on `just_audio` — exactly what `audio_service` is built to wrap. That means Android Auto support for My MP3s/recordings can be built as **new files only** (a new `audio_handler.dart` that talks to the same underlying player, new manifest entries) without touching `player_screen.dart`, `tts_player_screen.dart`, or anything else that already works. Zero risk to the current app, in-app behavior identical whether or not a car is plugged in.

**Net change to this plan:** skip any player-consolidation refactor. Do Phases 0-4 below (MP3s/recordings over Android Auto) as pure addition whenever it's worth the time — no urgency, since the main vehicle doesn't have Android Auto anyway. Leave Phase 5 (Read Scripture over Android Auto) shelved indefinitely unless it later turns out to matter enough to justify touching the TTS reading screen — which, per the note above, isn't a hard prerequisite for anything else and shouldn't be done "just in case."

## What's realistic vs. not (read this first)

Android Auto does not let any app render custom screens on the car display — that's a platform-level driver-distraction restriction, not a Flutter limitation. Every app is boxed into one of a small set of pre-approved templates. For an audio app like this one, that's the **Media template**: a browsable list plus standard transport controls (play/pause/skip/seek), track title, and a progress bar.

That means:
- **Achievable:** browsing your collections/MP3s and Read Scripture books from the car screen, tapping one to play it, and controlling playback (play/pause/skip/seek) from the car screen or steering wheel buttons.
- **Not achievable, ever, on the car screen itself:** the caption display, the note-taking screen, typing a note. There's no workaround for this — it's an OS restriction.
- **A real middle ground:** Android's MediaSession supports custom action buttons beyond play/pause/skip, and those DO show up in Android Auto's control row. A "Add Note" button next to Play/Pause is realistic, and fits the hands-free driving use case well — tap it, it starts recording your voice note the same way pausing already does today, no screen reading/typing required.

## Phase 0 — Feasibility spike (do this before anything else)

Goal: prove the toolchain and test setup actually work on your hardware before investing in the full build.

- Confirm you can actually **test** Android Auto integration on your setup. The Galaxy Tab S10 is a tablet — the Android Auto companion app (the one that projects to a car head unit) is built for phone form factors, and Samsung tablets aren't always able to install/run it from the Play Store. This needs to be checked early, because it determines your whole test strategy:
  - Best case: Android Auto app installs and runs fine on the Tab S10, and Google's **Desktop Head Unit (DHU)** tool (connects over `adb`, simulates a car screen on your Windows PC, no actual car needed) works against it.
  - Fallback if not: test via an Android phone (yours or borrowed) instead of the tablet, or via an Android Studio emulator image that includes Play Store + Android Auto.
- Add the `audio_service` package (pairs natively with `just_audio`, which this app already uses for playback — good news, no playback-engine swap needed) and get the barest possible "hello world" media session running: one hardcoded track, play/pause only, showing up in the DHU. Don't touch collections/browsing/notes yet. This is the go/no-go checkpoint.

## Phase 1 — Core media session (play/pause/skip/seek from the car)

- New file, `lib/services/audio_handler.dart`: a `BaseAudioHandler` (with `QueueHandler`/`SeekHandler` mixins from `audio_service`) that wraps the existing `AudioPlayer` currently inside `lib/services/audio_player_service.dart`. It forwards play/pause/seek/skip calls to the existing player and republishes `just_audio`'s position/duration/playing streams as `audio_service`'s `PlaybackState`/`MediaItem` streams — no change to how playback actually works, just a second layer of controls plumbed on top.
- Wire up `AudioService.init(...)` in `main.dart`.
- Android manifest changes: foreground service declaration + `MediaButtonReceiver` (both provided by the `audio_service` plugin's own setup docs), `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions, and an `automotive_app_desc.xml` resource declaring this as a `media`-category app (this is the file Android Auto checks to decide your app is eligible to show up at all).
- Checkpoint: play/pause/skip/seek for a single file works from the DHU, survives the screen locking/app backgrounding, shows up on the lock screen too (that part's free — same MediaSession powers both).

## Phase 2 — Browsable library (folders/list on the car screen)

- Implement the browse-tree callbacks (`getChildren` in `audio_service`) mapping to what already exists in `SimpleStorage`:
  - Top level: your Collections (from `loadCollectionNames()`), same grouping as My MP3s today.
  - One level in: the AudioFiles in that collection, excluding any `tts:`-prefixed synthetic entries (Read Scripture doesn't fit this model — see Phase 5).
  - Keep it to two levels max — Android Auto discourages deep menu nesting for safety, and a 3+ level tree (Collection → Book → Chapter, say) would be a bad fit for the car screen even if technically possible.
- Tapping an item calls `playFromMediaId`, which should reuse the exact same "start/resume a Session" logic `player_screen.dart` already has (create or find the Session, resume from `lastPositionMs`) rather than duplicating it — this is Dart logic that already exists and just needs to be reachable from the audio handler instead of only from a widget.
- Checkpoint: browse My MP3s' collections from the DHU, tap a file, it plays and resumes where you left off exactly like opening it from the app does today.

## Phase 3 — "Add Note" custom action

- Add a custom action (icon + label, e.g. "Add Note") to the `PlaybackState.controls` list the audio handler publishes — this is what makes it show up as an extra button in Android Auto's control row.
- The tricky part: the existing voice-note recording flow (`_startRecordingNote()` in `player_screen.dart`) is written as widget code — it shows `AlertDialog`s for microphone-permission problems, expects a `BuildContext`. None of that can happen headlessly from a car-screen button tap. This needs the actual start/stop-recording logic pulled out into a plain service method that:
  - Assumes microphone permission was already granted (check/prompt for it from the phone/tablet UI before driving, not from the car).
  - Gives feedback without a screen — a short tone or vibration for "recording started" / "note saved" instead of a dialog or snackbar.
- Checkpoint: tap "Add Note" from the DHU, speak a note, it shows up in My MP3s → that file's sessions afterward exactly like a note taken from the app screen would.

## Phase 4 — Testing matrix (before calling any of this done)

- Browse every collection level, confirm nothing crashes on an empty collection.
- Play/pause/skip/seek from: the DHU screen, and (if testable) real steering-wheel hardware buttons.
- Lock screen / notification controls still work (should come for free from the same MediaSession).
- Add Note end-to-end, including the microphone-permission-not-granted case (should fail gracefully, not crash the media session).
- Backgrounding: lock the phone/tablet screen mid-playback, confirm the foreground service keeps it alive and Android Auto stays in sync.
- Phone call interruption: confirm the existing "false paused for phone call" suppression logic (see project memory) doesn't get confused by the new playback path.
- Resume-position correctness after switching between the car screen and the in-app screen mid-session (both should agree on where you left off, since they share the same `SimpleStorage` Session data).

## Phase 5 — Read Scripture over Android Auto (separate, harder problem — treat as a stretch goal)

Read Scripture doesn't play a real audio file today — `flutter_tts` speaks each verse live, with no underlying scrubbable audio stream the way an MP3 has. MediaSession's model assumes a real position/duration you can seek within, which doesn't naturally exist for live TTS. Two options, worth a dedicated investigation before committing to either:

- **Pre-synthesize to a file:** have `flutter_tts` (or another TTS engine capable of synthesize-to-file) render each verse/chapter to an audio file first, then feed that into the exact same `just_audio` + `audio_service` pipeline built in Phases 1-3 — at that point Read Scripture just becomes another playable file, and none of Phases 1-3's plumbing needs to change. This is probably the cleaner path if it's technically supported by whatever TTS engine you're using, but needs to be verified first.
- **Skip Android Auto for Read Scripture entirely, at least initially** — ship Phases 1-4 for MP3s/recordings only (the well-trodden, standard case), and revisit Read Scripture-over-Android-Auto as a follow-up once the MP3 side is proven out.

## Rough sizing

Phases 0-4 (MP3/recording playback + browsing + Add Note button, fully tested) is the realistic first milestone — a real, multi-round build, not a single session. Phase 5 (Read Scripture over Android Auto) is a genuinely open technical question and should be scoped separately once Phase 0's feasibility spike confirms the toolchain works on your actual hardware.
