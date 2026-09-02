# Voice-following teleprompter scroll — build plan

**Written:** 2026-08-18 (round 28)
**Status:** design only, nothing built yet
**Asked for by:** Will, after the round-27 fresh-eyes review

---

## What it is

Instead of the text scrolling at a fixed pace you have to keep up with,
the app listens to you read and moves the text to match where you actually
are. Fall behind, it waits. Speed up, it speeds up. Stop to explain
something off-script, it holds until you come back.

This is the difference between a metronome and an accompanist.

---

## First, an important correction

In conversation the assumption was that this feature would need an
internet connection, like the round-26 "Analyze for Emphasis" feature does.

**It wouldn't.** Whisper (`whisper_ggml`) runs entirely on-device — it's
what already generates captions for imported MP3s with no network at all.
A voice-following teleprompter built on Whisper would work in a basement
with the wifi off.

That matters because it removes the main objection. This can be a normal
part of the app, not a connected-only extra.

---

## Why it's still not a small job

The problem isn't the recognition. It's that **Whisper is a batch
transcriber, not a live one.** You hand it a finished audio file and it
hands back text. It has no concept of "tell me what you're hearing right
now."

So the feature can't just call Whisper and read the answer. It needs a
loop that repeatedly captures a short slice of the last few seconds,
transcribes that slice, and figures out where those words land in the
script. Everything hard about this feature lives in getting audio *out*
of the recorder in slices while the real recording continues untouched.

---

## Three ways to get the audio, and what's wrong with each

### Option A — run a second recorder just for listening

Start a second `record` instance alongside the one making the real
recording, and feed only the second one to Whisper.

- **Simplest to write.** The existing recording path isn't touched at all,
  so a failure here can't corrupt a take.
- **Probably doesn't work.** Android generally allows one microphone
  capture per app; a second `AudioRecord` on the same input usually fails
  outright or silently starves the first. **This is the single biggest
  unknown and the cheapest one to test** — see the spike below.

### Option B — one microphone stream, split two ways *(most likely correct)*

Capture once using `record`'s PCM stream mode (`startStream()`), and split
that one stream in software: write it to disk as the real recording, and
keep a rolling few-seconds buffer for Whisper.

- **Architecturally right.** One mic consumer, no contention, full control
  of the buffer.
- **Costs the AAC encoding.** Today recordings save as `.m4a`/AAC at about
  1 MB/minute. A raw PCM stream written straight out is WAV — roughly
  **ten times larger**. For someone who has talked about recording the
  whole Bible (already a 4–5.5 GB project in AAC), 40–55 GB is not
  acceptable. So this option needs an encode step: either re-encode to
  m4a after the recording ends (needs an encoder on-device — the same
  unresolved tooling question that stalled the filler-word-removal idea),
  or write WAV and accept that recordings must be converted before they're
  kept.
- **Rewrites the recording path**, which is the one part of this app that
  has been working reliably since early on. Real regression risk.

### Option C — don't use Whisper at all

Use Android's built-in `SpeechRecognizer` (via a plugin like
`speech_to_text`) purely for position tracking, leaving `record` to make
the actual recording.

- **Purpose-built for live recognition** — it streams by design.
- **Same mic-contention question as Option A**, and it's designed for
  short utterances (it likes to stop after a pause), so it would need
  constant restarting across a long reading.
- **On-device recognition isn't guaranteed.** Modern Android can do it
  locally, but on some devices/configurations `SpeechRecognizer` reaches
  for the network. That would quietly reintroduce the internet dependency
  this feature doesn't otherwise have — unacceptable without verifying
  behavior on the actual Tab S10.

---

## The matching logic (the easy half)

Once there's recognized text, finding the place in the script is
straightforward and low-risk:

1. Normalize both sides — lowercase, strip punctuation. Whisper won't
   reproduce the BSB's punctuation, and it doesn't need to.
2. Search only a **window** around the current position — say 40 words
   back and 150 words forward. Never search the whole passage: repeated
   phrases ("and it came to pass") would otherwise throw the position
   across the book.
3. Score candidate positions by matching word runs, tolerating gaps and
   misrecognitions. Longest-common-subsequence over a short window is
   plenty; nothing exotic needed.
4. Require a **confidence floor** before moving. Below it, do nothing and
   let the fixed-pace scroll carry on. Silence, an aside, a cough, or a
   bad transcription should never yank the text somewhere surprising.
5. **Ease toward the target**, never jump. Adjust the effective scroll
   speed to close the gap over a second or two. A teleprompter that
   snaps is worse than one that's slightly behind.

The round-27 pacing rework helps here: the scroll rate is already computed
per-frame from a words-per-minute figure, so voice-following can simply
nudge that number up or down instead of fighting a fixed animation.

---

## Recommended path

**Do a 30-minute spike before designing anything further.** Build a
throwaway screen that:

1. Starts the normal recorder.
2. Tries to start a *second* capture at the same time.
3. Reports on screen whether both are running and whether both produce
   audio.

That one test decides everything. If a second capture works, Option A is
viable and this becomes a genuinely modest feature — the real recording
path is never touched. If it doesn't, the choice is Option B (and with it
the whole audio-format question) or Option C (and with it the on-device
recognition question), and the feature is a substantially bigger project
that deserves its own decision.

**Do not start with Option B.** Rewriting a working recording path on
spec, before knowing whether the much cheaper option is available, is
exactly the kind of rework this project has deliberately avoided.

---

## Suggested fallbacks regardless of which option wins

Even a perfect implementation will lose the place sometimes — an aside, a
long pause, a passage read from memory. The feature should be built
assuming that:

- **Always overridable.** The existing pause, nudge, and speed controls
  keep working exactly as they do now.
- **Always optional.** A toggle in the teleprompter, off by default. With
  it off, everything behaves exactly as it does today.
- **Visible state.** A small indicator showing "following your voice" vs.
  "fixed pace" so it's never a mystery which one is driving.
- **Graceful degradation.** If confidence stays low for a while, fall back
  to fixed pace on its own and say so, rather than drifting or freezing.

---

## Related open items in this project

- Filler-word ("um"/"ah") removal hit the **same on-device audio
  encoding/splicing question** as Option B. If that tooling ever gets
  resolved, both features get much easier at once — worth solving once,
  deliberately, rather than twice by accident.
- Long Whisper caption runs still have no true cancel button; the proposed
  fix there (chunked transcription) shares real machinery with the
  slice-and-transcribe loop this feature needs. Building either one makes
  the other cheaper.
