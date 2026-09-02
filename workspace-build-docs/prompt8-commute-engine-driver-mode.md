# Pre-Cached Commute Engine & Driver Mode — Technical Specification

**Reality check before the spec (second one in a row, worth reading):** this prompt asks for `scriptureapp://` custom URI schemes and hardware media button integration (steering wheel / Bluetooth headset controls). Those specifically require a **native mobile app** (iOS/Android) or at minimum a PWA with real OS-level registration — a browser tab loaded from a website cannot register a custom URI scheme or claim system media-button events. So this prompt, more than any before it, assumes a platform Scripture Workspace doesn't currently have (it's an HTML site today, not an installed app). I've written the full spec below as if that platform exists, since the architecture itself is valid either way — but flagged every point where the native-vs-web distinction changes what's actually buildable, and the real decision is in §6.

---

## 1. Commute Queue & Pre-Caching Engine

### 1.1 Builds directly on Prompt 7's Tier A/One-Touch Pre-Cache
The Commute Engine doesn't introduce new storage — it's a **playback controller** reading from the `commuteAudio` and `precacheQueue` IndexedDB stores already defined in Prompt 7. No new sync logic needed here; this layer is purely about sequencing and playback state.

### 1.2 Queue Composition (per day)
```js
{
  day: 47,
  date: "2026-08-02",
  queueItems: [
    { type: "scripture-audio", ref: "matthew-13:1-23", duration_s: 340 },
    { type: "commentary-summary", ref: "matthew-13:1-23", duration_s: 180 },
    { type: "small-group-prep", weekId: "parables-wk1", duration_s: 90 }
  ],
  totalDuration_s: 610,
  cacheStatus: "ready" // "pending" | "partial" | "ready" | "stale"
}
```

### 1.3 Queue Controller Behavior
- **Continuous playback:** items play back-to-back with a brief (1.5s) audio-cue transition between types (a soft tone distinguishing "now entering commentary" from "now entering scripture") — this replaces visual cues the driver can't safely read.
- **Auto-advance:** on item completion, immediately begins the next; a completed day's queue loops back to a "you're caught up" audio message rather than silence or abrupt stop.
- **Skip/reorder:** available via voice or steering-wheel controls only in Driver Mode (no requirement to look at the screen).

---

## 2. Driver Mode UX & Voice Interaction

### 2.1 Screen Layout (post "START COMMUTE" tap)
Extends Prompt 4's Driver Mode rules directly:
- Top: current item type + reference, in the 28px-minimum text size already specified.
- Center: single large play/pause toggle (primary), skip-forward flanking it — no more than these 2 transport controls plus the voice-capture icon are visible, per Prompt 4's 3-control max.
- Bottom-center: 96px voice-capture icon (fixed, per Prompt 4 spec).
- No scrolling, no menus, no text entry fields anywhere in this mode.

### 2.2 Hands-Free Voice Capture
**Activation:** tap-to-talk on the 96px icon (reliable, works with gloves/one-handed) as primary; keyword activation ("Hey Study Hub, note that") as secondary, since always-on keyword listening has real battery/privacy tradeoffs worth flagging to you as a product decision, not just an engineering default.

**Capture workflow:**
1. Icon tap → short confirmation tone (not visual, audio-only) → recording starts.
2. On release/second tap → recording stops → tone confirms save.
3. Auto-tagged metadata attached to the voice note:
   - Timestamp (device clock)
   - Current scripture reference (from queue position at capture time)
   - Audio playback position (seconds into current item, so "what was playing when I thought of this" is preserved)
4. Voice notes are stored raw (not transcribed live — transcription is a Tier B/cloud operation per Prompt 7's boundary, deferred until reconnection) for post-commute review.

### 2.3 Post-Commute Review
A dedicated review screen (only shown outside Driver Mode) lists captured voice notes grouped by day, each playable inline, with the auto-tagged scripture reference as a jump-back link into that passage's full study room.

---

## 3. System Deep-Linking & Hardware Integration

### 3.1 URI Protocol Schema
```
scriptureapp://commute/launch?plan=365day&day=47
scriptureapp://commute/voicenote?ref=matthew-13:1-23&position=340
scriptureapp://study/open?ref=john-1
```
**Platform note:** these require native app registration (`Info.plist` URL scheme on iOS, intent-filter on Android) — this doesn't work from a website. If staying web-based, the closest equivalent is a PWA with `share_target` and deep-link-style query params on regular HTTPS URLs (`https://studyhub.app/commute/launch?...`), which works in-browser but can't be triggered from, e.g., a car's voice assistant the same way a registered native scheme can.

### 3.2 Background Audio Service Lifecycle
- **Native app:** standard background audio session (iOS `AVAudioSession` category `.playback`, Android foreground `MediaSessionService`) — survives screen lock, interruption handling (phone calls pause/resume automatically).
- **Web/PWA equivalent:** Media Session API (`navigator.mediaSession`) provides lock-screen controls and metadata, but background playback reliability varies more by browser/OS than native — worth real device testing before relying on it for a driving use case specifically.

### 3.3 Physical Media Button / Steering Wheel Controls
Standard media key mapping (works via Bluetooth AVRCP on both native and reasonably well on web via Media Session API):
| Button | Action |
|---|---|
| Play/Pause | Toggle playback |
| Next | Skip to next queue item |
| Previous | Restart current item (not previous item — matches user expectation of "back to start of what I'm hearing," per common podcast-app convention) |
| Long-press (if available) | Trigger voice capture — native only; not reliably exposed to web apps |

---

## 4. Safety-First Design Notes

- **No silent failures while driving:** every state change (playback error, cache miss, note-save failure) gets an audio cue, never a screen-only indicator — carried over from Prompt 4/7's no-silent-failure principle, and especially critical here.
- **No text input ever appears in Driver Mode** — this is a hard rule, not a preference, given the use case.
- **Auto-exit Driver Mode is deliberately NOT automatic on stopping** (e.g. via detected speed) — false positives (stopped at a light) would be more disruptive than helpful; exit stays a deliberate action (tap or voice command "end commute").

---

## 5. Dependency Check

This module assumes: (a) Prompt 7's pre-cache/storage layer, and (b) a resolved backend decision for transcription and any live sync of voice notes. Both are still open per Prompt 7's tracker entry — worth resolving before this gets built for real, not just specced.

---

## 6. The Actual Decision You Need to Make

Before Prompt 8 becomes buildable rather than theoretical: **is Scripture Workspace staying a website (PWA-enhanced at most), or becoming a native mobile app?** This changes:
- Whether `scriptureapp://` links can exist at all
- Whether steering-wheel long-press-to-voice-note is reliable or best-effort
- Whether background audio survives screen lock consistently

If native is off the table for now, I'd recommend I rewrite §3 as a **PWA-realistic version** next, so the spec matches something actually shippable rather than describing an app that doesn't exist. Your call.
