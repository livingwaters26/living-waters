# Offline Whisper Setup Guide (Commute Notes)

This guide is for adding **real on-device speech-to-text** so:

1. **Captions** show the actual scripture words (not placeholder text)
2. **Your voice notes** become readable text automatically

Everything runs on the phone. After the model is downloaded once (on Wi‑Fi), it works with **no internet**.

You do **not** need to understand the technical details. Follow the steps in order.

---

## What is Whisper?

Whisper is an AI model that turns speech into text.  
“Offline Whisper” means the model lives on your phone and never sends audio to the cloud.

We use a Flutter package that runs **whisper.cpp** (a fast version of Whisper) on Android.

---

## Two jobs in our app

| Job | When it runs | How long |
|-----|----------------|----------|
| **Full MP3 → captions** | Once per scripture file (when you first open it, preferably on Wi‑Fi + charging) | A few minutes for a chapter |
| **Short voice note → text** | Every time you finish a spoken note | A few seconds |

The heavy work (full MP3) is one-time. Day-to-day note transcription is light.

---

## Recommended package (2026)

**Primary recommendation for Android:** `whisper_ggml` or `whisper_edge`

Both use whisper.cpp on-device.

| Package | Good for | Notes |
|---------|----------|--------|
| **whisper_ggml** | File transcription + optional live | Popular, multi-platform, active |
| **whisper_edge** | Android/iOS, model download built-in | Clean API, timestamps, progress |

Either works. We’ll wire one into `TranscriptService` and the note-finishing code.

**Alternative:** `sherpa_onnx` — also fully offline, sometimes lighter; different model format.

---

## Model size (pick one)

Smaller = faster + less storage. Larger = more accurate.

| Model | Approx size | Use when |
|-------|-------------|----------|
| **tiny** / tiny-q5 | ~30–40 MB | Testing only; rough quality |
| **base** / base-q5 | ~60–75 MB | **Best default for phones** |
| **small** / small-q5 | ~180–250 MB | Better accuracy if the phone is strong |
| larger | 500 MB+ | Tablets / high-end only |

**Recommendation for you:** start with **base** (or `baseQ5_1` / `base.en` if English-only scripture).

English-only models (`.en`) are a bit more accurate for English at the same size.

---

## High-level setup steps

### A. On your computer (after the app already runs)

1. Open `pubspec.yaml` in the `commute_notes` folder.
2. Add one line under `dependencies:`, for example:

```yaml
  whisper_ggml: ^2.6.0
```

(or the current version of `whisper_edge` if we choose that package)

3. In the terminal, inside the project folder:

```
flutter pub get
```

4. Rebuild:

```
flutter run
```

### B. First launch on the phone (needs Wi‑Fi once)

1. The app downloads the Whisper model (~60 MB for base).
2. Prefer **Wi‑Fi + charging** (you already keep the device charged on the commute).
3. After download, the model stays on the phone. No internet needed later.

### C. Generating captions for an MP3

1. Import the MP3 as usual.
2. Open a Session (or use a “Generate captions” button we’ll add).
3. The app runs Whisper on the whole file **once**.
4. Timed segments are saved (same system as today’s placeholder captions).
5. After that, scrolling captions show the real words.

This can take a few minutes for a long chapter. Do it at home, not on the road.

### D. Voice notes

1. You speak a note (mic button) as you already do.
2. When you stop, the short clip is saved (already working).
3. With Whisper wired in, the app transcribes that short clip offline and stores the text in the note.
4. Export then includes real text instead of “(Voice note recorded…)”.

---

## Audio format note (important)

Whisper works best with:

- **16 kHz**
- **Mono**
- **WAV** (or PCM)

Our voice recorder currently saves `.m4a`. The Whisper package may need a quick conversion step (many packages include helpers, or we convert with a small library).  
Full MP3s are converted or decoded by the package before transcription.

You don’t need to do this by hand — it belongs in the app code.

---

## How this plugs into Commute Notes

We already have:

- `TranscriptService` — loads/saves timed segments, updates captions by position  
- Voice note files saved to disk  
- Export that includes `captionContext` + note text  

What still gets added:

1. Download + load Whisper model once  
2. `TranscriptService.createFromAudio(filePath)` → real segments instead of placeholder  
3. After voice recording stops → `transcribe(shortClip)` → put text into `Note.text`  
4. Progress UI (“Generating captions 40%…”) so long MP3s don’t look frozen  

---

## Practical plan for you

### Tomorrow (day 1)
- Get the app running with **TOMORROW_MORNING.md**
- Use **typed notes** + timestamps + export
- Voice clips still save for later

### Next coding session (Whisper)
1. Add the package to `pubspec.yaml`
2. One-time model download screen
3. “Generate captions” for an imported MP3
4. Auto-transcribe short voice notes when you stop recording

### After that
- Captions = real scripture text  
- Spoken notes = real text in the list and in the export for Grok  

---

## Permissions reminder

Microphone permission is already planned (`RECORD_AUDIO`).  
Model download needs **internet only the first time**.  
After that, fully offline.

See also: `PERMISSIONS.md` and `android_permissions_snippet.xml`.

---

## Common questions

**Will this drain the battery?**  
Full-chapter transcription is the heavy part — do it while plugged in. Short voice notes are quick. Captions during playback only display saved text (very light).

**Does it work with no signal on the commute?**  
Yes, after the model and any MP3 transcripts are already on the device.

**What if transcription is wrong?**  
You can edit the note text later. Typed notes are always exact. For scripture, clear audio + `base` or `small` model is usually very good.

**Can I use it only for voice notes first?**  
Yes. We can wire short-note transcription before full-MP3 captions if you prefer.

---

## Summary

| Item | Status |
|------|--------|
| App playback, sessions, notes, export | Ready (see TOMORROW_MORNING.md) |
| Offline Whisper package | **`whisper_ggml` is in the project** |
| Recommended model | **base** (~60–75 MB, downloads once) |
| Full MP3 → real captions | **Wired** – CC button in the player |
| Voice note → text | **Wired** – when you stop the mic |
| After first model download | Fully offline on the commute |

**You don’t need to learn Whisper.** Tap **Generate real captions** once per MP3 (Wi‑Fi + charging). Spoken notes are transcribed automatically when you stop recording.
