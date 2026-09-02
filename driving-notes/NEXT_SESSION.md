# Next session — pick up here

**Last updated:** 2026-08-24 (round 34)

This file is the up-to-date pickup point. Full history/rationale for older
resolved rounds lives in project memory (`commute_notes.md`) - this file
now only tracks what's still open plus quick reference info.

## START HERE next time: confirm round 34's blank-screen fix on-device

**Round 34 fixed a real regression** - round 33's styling growth caused
the MP3 player screen to render blank (no reading box, no transport
buttons) in the release build. See the "ROUND 34" section below for the
root cause and the fix (both player screens' bodies now scroll instead of
using `Expanded`/flex, which was silently collapsing to zero height with
no error in release mode). **This has been pushed but NOT yet rebuilt and
confirmed on the user's tablet as of this note - do that first.**

Everything below this point (rounds 32-33) is otherwise confirmed working
by the user, including the crash fix and the stereo-deck redesign itself.

**Round 32 (2026-08-24): "grok jacked up my project" — the app crashed
outright when importing an MP3. Fixed, but NOT YET CONFIRMED by the user
(pushed at the end of a session that ran out of time).**

Context: the user had a separate AI (Grok) work on this codebase
independently. It left `audio_files.json` on the tablet genuinely malformed
(confirmed via a real Flutter crash log), and none of `SimpleStorage`'s
JSON loaders had any error handling — `loadAudioFiles()` did a raw
`jsonDecode(text) as List<dynamic>` with no try/catch, so a corrupted file
threw uncaught. That propagated straight through `loadCollectionNames()`
into `ImportFolderScreen._loadCollections()` (called from `initState()`,
also unprotected), which crashed the entire app the moment the import
screen tried to open — "right now, it's not working in any manner."

Grok had already written a resilient loader (`lib/services/safe_json.dart`,
`SafeJson.readList()` — salvages a truncated JSON array where possible,
backs up an unrecoverable file to `<name>.json.bad`, returns `[]` on total
failure) but never wired it into anything. **This round wired it in**:
every loader in `simple_storage.dart` (`loadAudioFiles`, `loadSessions`,
`loadNotes`, `loadCollectionNames`, `addCollectionName`,
`removeCollectionName`) now goes through `SafeJson.readList()` instead of
a raw `jsonDecode`. Also added a belt-and-suspenders try/catch around
`ImportFolderScreen._loadCollections()` itself, so even a case SafeJson
can't handle just falls back to "Uncategorized" with a snackbar instead of
taking the app down.

**User's explicit priority for this fix**: "I don't need to recover
anything... we can fix it from here to work correctly... right now, it's
not working in any manner." — this was a functional fix, not a data
recovery effort. If `audio_files.json` really was malformed, the user's
library will come back empty on next launch (not a crash) with the bad
file backed up alongside it as `audio_files.json.bad`.

**CONFIRMED FIXED** - user rebuilt and reported "everything was working
and my mp3s were back." Worth noting for future reference: the library
DID come back on its own, which confirms the earlier read that "all my
mp3s are gone" was a masked JSON parse failure (Grok's try/catch in
`library_screen.dart` swallowing the error and showing an empty list),
NOT actual data loss. No recovery step was ever needed - wiring SafeJson
into the loaders was sufficient, because it repairs the malformed file
in place on first read.

Also this round, separately: added `translation`/`narrator` fields to
`AudioFile` (`models.dart` - `toMap()`/`fromMap()`/`copyWith()` all
updated) as groundwork for the library hierarchy rebuild below - empty
string default, fully backward compatible, not yet used by any UI. And
fixed the caption-sync/speed knob layout on the player screen (user:
"nudge captions... works well its just needs to look better... dials are
misplaced") - Speed and Nudge Captions now sit in matching equal-width
bordered panels side by side instead of Speed hugging the left edge with
Nudge Captions adrift in leftover space. **Confirmed working** - user
rebuilt and sent a screenshot: "this is what I want."

The app also visibly rebuilt and ran fine end to end (player screen,
captions, dials) after the SafeJson wiring change, which is a good sign
for the crash fix - but the user hasn't explicitly confirmed importing an
MP3 works yet (the actual crash from the Grok issue). **Still worth
explicitly re-testing an MP3 import next session** before calling that
one fully closed.

**Same round, later**: user showed a Gemini-generated mockup image as "what
I want" for this screen - turned out to be a loose style reference, not a
literal spec ("i didnt give any specifics i just ask gemini to come up
with a nice design"). Clarified via AskUserQuestion that the two things
worth keeping from it were: nothing about the unified-card dial styling or
the merged Play/Pause button (not requested), but the small `<`/`>`
arrows gave the user the idea of press-and-hold continuous rewind/
fast-forward. **Built and pushed**: the existing 15s skip buttons in
`player_screen.dart` (now `_skipButton()`, replacing the old
`OutlinedButton.icon` pair) still do a normal 15s jump on tap, but
press-and-hold now seeks continuously (2s per 150ms tick, via
`_startContinuousSeek()`/`_stopContinuousSeek()`/new `_seekTo()` helper)
and the caption scrolls along with it in real time, for as long as it's
held - saves the session position once when released, not on every tick.
NOT yet confirmed by the user - check on this next session too.

**Same round, one more pass**: user showed the Gemini mockup again ("the
one i want... see difference?") - this time asking for the actual visual
match, not just the hold-to-scrub idea it inspired. Rebuilt the bottom
half of `player_screen.dart` to match:
- **Dial card**: Speed and Nudge Captions now share ONE card with a
  divider between them (`_dialCard()`), instead of two separate
  side-by-side cards (round 32). Small `<`/`>` chevrons on the outer edges
  do a plain tap-to-skip-15s - NOT press-and-hold (user explicitly said
  "the scroll ffw back isnt on there" for these - that continuous-seek
  behavior stays on the transport card's arrow buttons only, see below).
- **Transport card** (`_transportCard()`): Stop / rewind / a merged
  Play-Pause toggle / forward / a "15s" chip, all in one card. The
  rewind/forward buttons here DO support press-and-hold continuous seek
  (reusing round 32's `_startContinuousSeek`/`_stopContinuousSeek`, now
  via a shared `_seekControl()` helper used by both this row and the dial
  card's chevrons).
- **Behavior change worth knowing about**: the merged Play/Pause button is
  a genuinely PLAIN pause/resume toggle (new `_pausePlaybackOnly()`) - it
  does NOT start recording a note. **Record Note kept its exact old
  behavior** (pause AND start recording a note - `_pauseAndRecord()`,
  unchanged) but moved out of the transport card into the secondary row
  below it, alongside Mute/Type Note, since it's a distinct action from a
  plain pause, not a resize of the same button. This is an actual UX
  change (before this round, there was no way to just pause without also
  starting a note recording) - flagged to the user, not yet explicitly
  confirmed as wanted vs. Record Note's old prominent/biggest-button
  placement. **Check this feels right next session** - if the user liked
  Record Note being the biggest/most prominent button, it can move back
  or get resized; the plain-pause/record-note split itself seems like the
  right read of the mockup regardless.
- The "15s" chip next to the transport arrows is currently just a label
  (shows the fixed skip length used by both the transport arrows and the
  dial card's chevrons) - not tappable yet, could become a real control if
  the user wants to change the skip length later.

NOT yet confirmed by the user - this was a same-session follow-up rebuild,
pushed but not rebuilt/tested on-device yet as of this note.

**Immediate correction, same round**: the plain-pause/Record-Note split
above was wrong - user caught it right away ("no i need play stop pause
to work like we had it, pause should take notes"). Fixed: the merged
Play/Pause button's pause action now calls `_pauseAndRecord()` again
(same as before this round) instead of the short-lived
`_pausePlaybackOnly()`, which has been removed entirely. The standalone
Record Note button (in the secondary row) is now just a second way to
reach the exact same action - both do the identical pause-and-record.
Play/Stop/Pause now work exactly like they did before the round-33
redesign; only the visual layout (unified dial card, transport card,
merged Play/Pause icon) actually changed. **Confirmed working by the
user** - rebuilt, tested every button, and confirmed: "this is what i
want."

---

## ROUND 33 (2026-08-24): full "stereo deck" visual rebuild of both players

Long iterative design session driven by a Gemini-generated mockup the user
kept comparing against. Everything below is PUSHED and confirmed by the
user - **see ROUND 34 below** for a real regression this round caused (the
player screen went blank) and its fix. The styling itself (carbon fibre,
reworked Screen Nudge, outline mic) is confirmed working as of Round 34.

**New shared file: `lib/widgets/stereo_panel.dart`.** Holds the whole
visual language so the two player screens can't drift apart again (they
each used to carry a private copy of the button helper):
- `CarbonPanel` - the faceplate widget. Real woven carbon fibre, not a
  gradient: a 16px tile is painted ONCE (2x2 cells of diagonal strands
  whose direction flips per cell - that alternation is what reads as an
  over/under weave) into a cached `ui.Image` via `toImageSync`, then
  repeated with an `ImageShader`. Deliberately NOT drawn cell-by-cell each
  frame - these panels rebuild constantly off the position stream, and
  that would have been thousands of draw calls per frame.
- `stereoKey()` - the bevelled round transport key: dark moulded surround,
  top-lit gradient across the cap, bright hairline on the upper edge, hard
  drop shadow. Flat filled circles read as icons printed on the panel;
  this reads as pressable.
- `stereoLitKey()` - backlit rectangular key (REVERSE/FORWARD, the nudge
  chevrons): top-lit gradient, glowing accent border, soft outer bloom.
- `stereoPanel()` / `stereoInset()` - the older plain brushed plate and the
  dark recessed inset, kept for trim pieces where texture would be noisy.
- **`StereoBacklight`** - the deck's backlight colour (6 presets: Ice Blue,
  Amber, Green, Red, Violet, White). Held in a global `ValueNotifier`
  rather than passed down, because both screens and every lit widget need
  it and it changes at any moment. Persisted BY INDEX via
  `SettingsService.getBacklightIndex()`/`setBacklightIndex()` (index, not a
  raw colour, so the setting stays valid if the palette is ever retuned).
  `StereoBacklight.ensureLoaded()` is called from both screens' initState.
  Drives: knob arc/needle/selected tick, lit key borders + glyphs, the
  seam glow, and "On time".
- `BacklightBuilder` - rebuilds a subtree when the colour changes.
- `StereoSeamGlow` - light spilling out of the seam between the two
  transport modules.
- `StereoBacklightSwitch` - a single glowing bulb key; click drops down the
  colour list. (Started as an always-visible row of six dots; the user
  asked for the bulb instead.)

**MP3 player layout** (`player_screen.dart`):
- Dial card: Speed knob and the Screen Nudge module share ONE carbon panel
  with a divider. "Speed" legend sits UNDER the knob like a panel legend.
- Transport: TWO separate carbon modules (STOP+REVERSE | FORWARD+PLAY)
  with a backlit seam between them, and the oversized PAUSE key straddling
  the gap, proud of both. Secondary row below: MUTE, TYPE NOTE, and the
  backlight bulb.
- **PAUSE keeps its long-standing behaviour** - pauses AND starts a voice
  note (`_pauseAndRecord`). It carries pause bars + an OUTLINE mic
  (`Icons.mic_none`), matched in size, on the cap face. A brief attempt to
  split this into a plain-pause toggle plus a separate Record Note button
  was rejected outright by the user ("pause should take notes") - don't
  re-introduce that split.
- Caption box: `minHeight: 260` plus flex 3 -> 5, so ~2 more lines show and
  the controls sit lower.
- Hold-to-scrub: tap REVERSE/FORWARD = 15s jump; press and hold = continuous
  seek at 2s per 150ms tick with the caption scrolling along, saving the
  position once on release. The nudge module's `<`/`>` chevrons are
  deliberately tap-only (user: "the scroll ffw back isnt on there").
- Screen Nudge module: dark outer box with a "Screen Nudge" legend (the
  live "+/-Ns" reading was removed at the user's request), containing
  [`<` key][recessed well][`>` key]. The well is DARKER than the module
  (it was lighter, which made it read as a pale grey slab pasted onto the
  carbon deck), and its keys are stadium pills, slate-tinted, bevelled.

**TTS player** (`tts_player_screen.dart`): same carbon panels, bevelled
keys, knob size and backlight bulb - but **its own controls**, per the
user's explicit instruction not to add buttons that don't belong: STOP /
previous VERSE / PAUSE / next VERSE / PLAY, and no Screen Nudge module
(nothing to sync against - the TTS voice IS the display).

**Knob** (`knob_dial.dart`): size 148 -> 172. Layered for real depth: wide
panel shadow, swept metallic bezel (a `SweepGradient`, so the ring catches
light top-left and goes dark bottom-right like turned aluminium), lit face
gradient, gloss, rim highlight, and a SHORT lit arc centred on the current
value (a fill running back to the minimum read as a progress bar and
flooded the dial). **The face is deliberately near-black** - an earlier
mid-grey face forced the white readout and ticks to compete with it and
made them look soft/blurry; the fix was darkening the face and cutting the
gloss, not dimming the text.

Also still open from before (unchanged, revisit once the crash fix is
confirmed): the library hierarchy design questions below.

The user has asked to revisit the deeper library hierarchy
(`LIBRARY_HIERARCHY_PLAN.md` - translation → narrator → book) but hasn't
answered the design questions needed before touching any code yet. **Ask
these three before writing anything** (don't start with the data model
change - see that doc's own "Next step" section):

1. **Non-Bible content placement** - should "Personal Readings"/sermons/
   teaching recordings sit in their own top-level section outside the
   Bible Translations branch (same as today), or get folded into the same
   tree somehow (e.g. as a pseudo-translation)?
2. **Rollout** - does the new tree browser replace `library_screen.dart`
   (My MP3s) entirely, or ship as a new screen alongside the current flat
   list so there's a fallback while it's new?
3. **Default expand** - fully collapsed at every level when the library
   first opens (matches today's folders), or pre-expanded down to the
   book level so everything's visible at a glance?

Everything below this is from the previous round and is CONFIRMED WORKING
by the user through real use - nothing else is currently pending
rebuild/verification.

- The Fr. Mike Schmitz/Berean caption bug (wrong voice on "Caption with
  Real Text") - fixed and confirmed.
- The "captions frozen" report on a 33-min Matthew 1-9 file - diagnosed as
  a chapter-range mismatch, confirmed fixed once redone with the correct
  range.
- Silent lead-in throwing off caption pacing - fixed via a "seconds of
  silence/intro" field on the chapter-range picker.
- CC dialog decluttered (single short explanation box, uniform button
  styling, Whisper-only timing warning moved to its own secondary
  confirmation) - confirmed working.
- Knob layout (side by side, always-labeled current value, thicker
  needle, bigger size) - confirmed working ("that works pretty good").
- **REAL BUG, found and fixed this round: poetry books (Psalms, Proverbs,
  Job, Lamentations, Song of Solomon, poetic stretches elsewhere) were
  losing almost all their verse text in "Caption with Real Text."** The
  Berean Standard Bible's data wraps each poetry line in an object like
  `{"text": "...", "poem": 1}` instead of a plain string (prose books like
  Matthew use plain strings, which is why this was never caught before).
  `_joinHelloAoContent()` in `bible_text_service.dart` only recognized
  bare strings, so it silently dropped every wrapped line and kept only
  stray leftovers like a bare "Selah" - meaning almost every verse in a
  Psalms/Proverbs/etc. range came back empty and got filtered out,
  leaving one leftover fragment to span the ENTIRE file (exactly why a
  Psalms 1-4 test looked completely frozen no matter how far the user
  skipped forward). Fixed to unwrap `{"text": ...}` objects too. Also
  added a one-time Bible-text cache version bump/wipe
  (`_wipeCacheIfSchemaOutdated`) so previously-cached poetry chapters get
  re-fetched with the corrected parsing instead of replaying the old
  broken data forever - this only touches the small on-disk Bible text
  cache, not the library/sessions/notes. **Confirmed fixed** - user
  regenerated Psalms 1-4 captions and confirmed real text now shows and
  advances correctly.
- **Caption sync knob fine-tuning.** Follow-up request after the Psalms
  fix: the "Caption sync" knob's steps jumped by 2s/5s/10s near the
  middle, too coarse to nudge precisely ("the speed would be better
  divided by 1 seconds not 5"). `_syncOffsetStepsSeconds` in
  `player_screen.dart` now generates every single second from -60 to +60
  (`List<double>.generate(121, ...)`) instead of the old sparse list -
  since the knob drags to an absolute angular position rather than
  clicking through steps, this doesn't slow down a big correction
  (dragging near either end still jumps straight to -60/+60 in one
  motion), it just adds precision everywhere in between. **Confirmed
  working** ("exactly what i needed").

**Not app-code, but delivered this round**: a full project overview
(`PROJECT_OVERVIEW.md`) and an updated Gateway pipeline reference doc
(`gateway_mp4_to_mp3_pipeline.md`, including the successful silence-trim
retune from this session) were written and zipped up for the user as a
"starting from scratch" reference package - no code changes involved,
just documentation to keep alongside the project.

---

## ROUND 34 (2026-08-24): fixed a real regression from round 33 - player screen went blank

After round 33's last push (carbon-fiber panels, the straddling PAUSE key,
the Screen Nudge module rewrite, and the caption box's `minHeight: 260`
change), the user rebuilt and reported the MP3 player screen was broken:
"nothing is there in player no reading box no play buttons just this" -
only the header, position slider, and dial card (Speed knob + Screen
Nudge) rendered. The caption/reading box above the slider, and everything
from the transport card down (transport card, Mute/Type Note/backlight
bulb row, notes section) were just blank black space.

**Root cause**: the body `Column` (inside `SafeArea`, no scroll view) mixed
`Expanded(flex: ...)` widgets (the caption box, the notes list) with a
growing pile of fixed-size content (bigger 172px knob, carbon-fiber panel
padding, the 100px straddling PAUSE key, the Screen Nudge module, etc).
Once round 33's sizing increases pushed the fixed content's total height
close to or past the screen's actual height, the `Expanded` flex children
got squeezed toward zero height (or content got positioned below the
visible screen edge) - and critically, **none of this throws or shows the
usual "RenderFlex overflowed" warning in a `--release` build**, because
that diagnostic is debug-only. So the screen just silently went blank
instead of showing any error. The `constraints: BoxConstraints(minHeight:
260)` added late in round 33 to the caption box (for "bring in 2 more
lines") made this worse without actually preventing it, since a
`ConstrainedBox`'s minHeight gets overridden by a tighter incoming
constraint from its `Expanded` parent rather than growing the parent.

**Fix, applied to BOTH `player_screen.dart` and `tts_player_screen.dart`**
(the TTS screen had the identical pattern from its round-33 "match the
MP3 player" pass, confirmed via grep even though the user only reported
the bug on the MP3 player):
- Wrapped the whole body `Column` in a `SingleChildScrollView`. This is
  the durable fix - no matter how tall future styling passes make the
  content, it will scroll instead of silently vanishing or getting cut
  off, in both debug AND release builds.
- Caption box: `Expanded(flex: 5, child: Container(..., constraints:
  BoxConstraints(minHeight: 260), ...))` → `Container(..., height: 260,
  ...)` - now a fixed height instead of a flex share with a conflicting
  minHeight, so it always renders at exactly the size the user asked for
  ("bring in 2 more lines"), independent of everything else's height.
- Notes list: `Expanded(flex: 2, child: ...)` → `SizedBox(height: 220,
  child: ...)` - same reasoning; `ListView.builder` still works fine with
  a bounded height inside the outer scroll view (a normal nested-scrollable
  pattern).

Balance-checked (`/tmp/balance_check.py`) and pushed to both files on the
user's PC. **NOT yet rebuilt/confirmed on-device as of this note - that's
the first thing to check next session** if this file is still the pickup
point. If the user reports anything looking different now (e.g. the
screen scrolling when it didn't before, or the caption box height feeling
off at 260px on their tablet), that's expected from this fix and can be
tuned, but the core "blank screen" bug should be gone.

## Agreed but NOT built: deeper library hierarchy

Long design conversation this round landed on a real plan - see
`LIBRARY_HIERARCHY_PLAN.md` in the project root for the full writeup
(tree diagram, confirmed decisions, still-open questions, rough build
scope). User confirmed the shape matches what they want ("yes thats how
Id like it") but explicitly wants to keep using the app as-is a while
longer before committing to the rebuild ("I'd have to use it to make
sure"). Read that file before touching `AudioFile.collection` or
`library_screen.dart` - don't start this from scratch, the design work is
done. (Note: the doc's one open question, CC vs. Text-from-scripture as a
toggle, is now resolved AND built - see the dual-captions section below -
`transcript_service.dart` no longer has the one-transcript-per-file
limitation it describes.)

## NEW (round 30): Playback speed, mp4 import, delete empty folders, "Continue your notes"

Several smaller, independent additions this round, all not yet build-tested:

**Playback speed slider (`player_screen.dart` + `audio_player_service.dart`).**
User recorded a reading at 2x and wanted to slow it back down on playback.
`AudioPlayerService.setSpeed()`/`.speed` wrap `just_audio`'s built-in
`setSpeed()` - real time-stretching (ExoPlayer), not pitch-shifted
resampling, so slowed playback still sounds like a normal voice. New slider
under the position bar, snapping to a hand-picked, non-uniform step list
(finer near 1x for small tweaks, coarser at the extremes): `[0.5, 0.6,
0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.0, 1.25, 1.5, 2.0]`.

**MP4 import.** `import_folder_screen.dart`'s file picker `allowedExtensions`
gained `'mp4'` alongside mp3/m4a/wav/aac/ogg - copy/import logic downstream
was already extension-agnostic, so no other changes needed. If a video-track
mp4 (not audio-only) ever gets imported, `just_audio` should still play its
audio track, just with no video shown - not tested with a real video file.

**Delete empty folders (`library_screen.dart` + `simple_storage.dart`).**
User deleted all their MP3s and had no way to remove the now-empty
collection folders. New `SimpleStorage.removeCollectionName()` (removes
from `collections.json` only - a collection can still reappear if any
AudioFile still references it, and the built-in seed collection 'Personal
Readings' isn't stored here so it can never be deleted this way). A small
trash icon now shows next to any folder with zero files (except 'Personal
Readings'), with a confirm dialog.

**"Continue your notes" on Home screen (`home_screen.dart`).** Long design
conversation (user: "let's talk about it" before building, several rounds
of back-and-forth) landed here. NOT a single "resume last session" shortcut
- user pushed back on that explicitly, since they run several studies
concurrently (e.g. Daniel one day, Psalms the next) and the most-recent one
isn't always the one they want. Instead: a horizontal strip of cards, ONE
PER BOOK/FILE, but only for files that actually have notes on them - user's
own framing: "I get home and want to export my notes, I didn't want to have
to go through each file/folder/session to find those." Ranked by the date
of each file's most recent note (not generic playback activity). Each card
shows the book title, a caption preview at the last position, a relative
date ("Today"/"Yesterday"/"N days ago"), and a note count badge. Tapping
opens straight back into that exact session (handles both real MP3
sessions via `PlayerScreen` and Read Scripture/TTS sessions via
`TtsPlayerScreen`, parsing the `tts:<translation>:<bookId>` synthetic path
and resuming at the book's saved `lastChapter`/`lastVerse`). Reloads after
returning from any screen so it stays current without restarting the app.

**Captions-ready badge (`library_screen.dart`).** Small "Captions ready"
label + icon now shows under any file that already has `transcriptReady ==
true`, so a long library doesn't require opening each file just to check -
directly replaces a workaround the user was about to build manually (a
"CCgen" tracking folder they'd move files into after generating captions).

**FIXED this round (later in round 30, after the section above was
written): dual captions + a real toggle.** The overwrite bug described
below is now actually fixed, not just diagnosed - user caught an earlier
summary overstating this ("i dont see toggle") and it's now really built.

- `transcript_service.dart`: transcripts are stored as `{"whisper": [...],
  "scripture": [...]}` instead of one flat array - `loadBundle()`/
  `saveKind(id, 'whisper'|'scripture', segments)` replace the old single
  `load()`/`save()` (both kept as thin back-compat wrappers). Old
  single-transcript files on disk are read in fine (treated as the
  'whisper' bucket).
- `AudioFile` gained `hasWhisperCaptions`, `hasScriptureCaptions`,
  `activeCaptionKind` ('whisper'|'scripture', default 'whisper'),
  replacing the old `transcriptIsEstimated` bool. `fromMap()` migrates old
  saved data automatically - no user action needed, no data lost.
- `player_screen.dart`: running Whisper CC and "Caption with Real Text" on
  the same file now saves BOTH instead of one overwriting the other. Once
  both exist, two chips appear under the caption box - "Whisper transcript"
  / "Real scripture text" - tap to switch which one is showing; the choice
  is remembered per file. This is the actual fix for the duplicate-session
  problem (no more need to start a throwaway session just to reach CC a
  second time).
- Caption sync control: for scripture-synced (estimated) captions only,
  since their timing is a proportional guess and can drift from the actual
  narration - appears under the caption box whenever scripture captions
  are the active kind. **This was originally built as a `captionSyncScale`
  multiplier (0.5x-1.5x, ±0.05 buttons) - that version is SUPERSEDED, see
  the "START HERE tomorrow" section at the top of this file: it's now a
  flat seconds offset (`captionSyncOffsetMs`) shown as a knob dial, not a
  multiplier or buttons.**

**Confirmed working (2026-08-20, on the build at that point): the toggle
switches correctly** - user tested on-device and confirmed the "Whisper
transcript" / "Real scripture text" chips switch which captions are
showing. Still unconfirmed: whether the choice is remembered after closing
and reopening the file. The sync control itself has since been rebuilt
twice more that same evening (seconds-offset, then knob dial) - see the
top of this file - so the original multiplier version's behavior is moot,
but whether the NEW version actually nudges timing correctly is still
unverified on-device.

**Also discussed, explicitly NOT built - deeper folder hierarchy.** User
wants something like Berean Translation -> per-narrator -> chapters,
scaling to multiple translations (KJV added on top) each with multiple
narrators. Real architecture question, deliberately deferred - user said
"let me use it a few days like it is" before this thread continued into
the session-per-caption-attempt problem and the notes-list solution above.
Still open for a future round.

## Round 29: Custom app icon (blue car/road/pause-bubble/mic design)

User provided AI-generated mockups (car on a road + speech bubble with a
pause icon + a microphone) in three color options and picked the blue one.
Replaced the default Flutter icon at all 5 Android launcher densities:
`android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`.

First attempt hand-drew a vector recreation instead of using the user's
actual image (the mockup's icon card wasn't a clean square). **User
rejected this** ("Why didn't you use the actual image I gave you? I don't
like yours. Your car is wonky.") - fair, a redraw was the wrong call when
the real pixels were right there. **Corrected**: cropped a true square
directly out of the user's actual uploaded mockup (`ChatGPT_Image_Aug_18
..._05_02_20_PM.png`, blue icon at x:[1033,1489] y:[216,744], 456x528) by
taking the full 456px width and centering a 456x456 square vertically in
that range - no stretching/distortion, minimal trim off the top/bottom of
the rounded-rect card. This crop is the real artwork now resized down to
all 5 mipmap sizes. This is a **legacy (non-adaptive)** icon setup - no
`mipmap-anydpi-v26/ic_launcher.xml` exists in this project, so just
replacing the 5 PNGs is the complete fix; no manifest changes needed.
**Lesson for next time:** if a source image crop isn't a clean square,
default to a centered square crop of the real pixels first - only fall
back to redrawing if the user says they'd rather have a fresh recreation.

**User asked whether icon choice could be made changeable/switchable from
within the app itself** (e.g. pick a different color later without a
rebuild). Answered but NOT built: Android supports this via
`<activity-alias>` entries in the manifest (one per icon variant, each
initially disabled except the active one, toggled at runtime via
`PackageManager.setComponentEnabledSetting`), but flagged real caveats
before recommending it: needs a full icon set generated per variant now,
adds several manifest entries, and many Android launchers cache the icon
and won't visually update until the app is removed and re-added to the
home screen or the device restarts - so "instant" switching isn't
guaranteed across all launchers. Left as a possible future add if wanted,
not started.

**Not build-tested** - please rebuild (a full rebuild, not hot
reload/restart, is typically needed for a launcher icon change to show up
- may also need to uninstall and reinstall if Android's launcher cached
the old icon) and confirm the app icon shows the new blue design on the
Tab S10 and in the app switcher.

**User confirmed (end of round 29, no rebuild done yet):** "I'll go with
what you have" - the real-crop blue icon (already pushed to all 5 mipmap
files) is the one to keep. No further icon changes needed - just the
rebuild/reinstall above whenever it's convenient.

## NEW (round 28): Teleprompter extracted to its own file + punctuation micro-pauses + voice-follow plan

User greenlit all three round-27 suggestions.

**Extracted to `lib/screens/teleprompter_view.dart` (NEW).** `TeleprompterView`
is a self-contained StatefulWidget owning its own scroll controller,
ticker, pacing (wpm), font size, countdown and pause state. It takes
`verses`, `label`, `emphasisMarks`, `isPractice`, `elapsedSeconds`,
`blinkOn`, `onStop` and knows nothing else about recording.
`record_reading_screen.dart` dropped from ~1200 to 708 lines and now keeps
only the loaded passage, emphasis marks, recording lifecycle and wakelock;
it renders `TeleprompterView(...)` where it used to build the whole thing
inline. The countdown now starts in the view's own `initState()`, so the
parent no longer triggers it. Keyed by `_teleprompterLabel` so loading a
different passage rebuilds the view's state from scratch.

**Punctuation-derived micro-pauses.** Text is now split into sentence-sized
`_Line`s at punctuation (`.!?…` = a full beat, `;:—–` = half a beat;
commas deliberately ignored - pausing at every one reads as stuttering).
Each line's *bottom gap* is the pause: at a constant pace, extra vertical
space with no words in it is real time to breathe. Gap scales with font
size (`_beatPixels = fontSize * 1.15`).
- **The subtle part**: pacing now divides by `_effectiveWords`
  (`realWords + totalBeats * 1.5`) rather than raw word count. Without
  that, the extra gaps would just inflate content height, the derived
  pixel rate would rise to match, and the pauses would steal their time
  back out of the words instead of adding to them. The 1.5-words-per-beat
  figure is a calibration, not an exact derivation (the exact version is
  circular, since content height isn't known until layout) - it's close
  enough that the feel is right.
- Emphasis marks still work: they're resolved against the whole chunk text
  then mapped onto whichever line contains them, with line-relative
  offsets. A mark straddling a sentence break is dropped rather than
  rendered half-styled. The verbatim-substring safety property from round
  26 is unchanged - text is still only ever sliced and reassembled.
- Only the first line of a chunk shows the verse/chunk number.

**`TELEPROMPTER_VOICE_FOLLOW_PLAN.md` (NEW) - design only, nothing built.**
Honest feasibility writeup for voice-following scroll. Key points:
- **Corrected a wrong assumption**: this would NOT need internet. Whisper
  is on-device. The user believed it would be a connected-only feature;
  it wouldn't be.
- The real difficulty is that Whisper is batch, not streaming - the
  feature needs to repeatedly slice recent audio while the real recording
  continues untouched.
- Three options laid out with honest tradeoffs: (A) second parallel
  recorder - simplest, but Android usually allows only one mic capture per
  app; (B) one PCM stream split two ways - architecturally right but
  rewrites the working recording path AND costs AAC encoding (~10x file
  size, unacceptable for a whole-Bible project without an encode step -
  the same unresolved on-device encoder question that stalled filler-word
  removal); (C) Android `SpeechRecognizer` - purpose-built for streaming
  but same mic-contention question and may quietly need network.
- **Recommended next step is a ~30-minute spike**, not a build: test
  whether two simultaneous mic captures work on the Tab S10. That one
  answer decides whether this is a modest feature or a big project.
  Explicitly recommends NOT starting with Option B.
- Matching logic (windowed fuzzy match, confidence floor, ease-don't-jump)
  is documented as the easy half, and benefits from round 27's per-frame
  wpm pacing since voice-follow can just nudge that number.

**Not build-tested** - please rebuild and check: the teleprompter still
looks and behaves as it did (it's the same UI, just relocated), the new
breath gaps after sentences feel natural rather than choppy, pace still
feels right at a given wpm now that pauses are counted, emphasis
bold/"·" marks still render correctly, and Practice mode + countdown +
Stop & Save all still work.

## NEW (round 27): Teleprompter rebuilt on words-per-minute + Today's Notes grouped by book

User asked for a fresh-eyes review ("is there a better way to build this,
particularly the teleprompter... one Barack Obama would use") plus a
specific Today's Notes request. Four real problems found and fixed, one of
which was an outright bug.

**BUG FIXED - screen timeout during a recording.** `record_reading_screen.dart`
never enabled `wakelock_plus` (only the Whisper caption run did). On a long
teleprompter reading the tablet screen would sleep, the text would vanish
mid-sentence, and the recording would keep running blind. Now enabled on
Start Recording and on Practice, released on stop and in `dispose()`.

**DESIGN FIX - pacing is now words-per-minute, not pixels-per-second.**
This was the root cause of round 25's complaint ("I wish the words were
bigger... and be able to slow it down a little more because the words
would be bigger so they'd be less" - user diagnosed the coupling
themselves). With a fixed pixel rate, enlarging the text meant fewer words
on screen at the same pixel speed = secretly demanding a FASTER read.
Now `_pixelsPerSecond()` derives the rate every frame from the passage's
REAL rendered content height divided by its actual word count, times the
chosen wpm. Font size and reading pace are now fully independent - 120 wpm
is 120 wpm at any text size, and a wordier passage automatically scrolls
proportionally faster in pixels to hold the same spoken pace. Speed chips
now read "Slower 95 / Slow 110 / Normal 130 / Fast 155" (real wpm numbers)
plus a fine-trim slider (70-190 wpm) for dialing in between presets.

**SMOOTHNESS - vsync Ticker instead of a 50ms Timer.** The old
`Timer.periodic(50ms)` + `jumpTo()` stepped the text 20 times a second,
which reads as stutter on continuous scroll. Now driven by `createTicker`
(`SingleTickerProviderStateMixin`) at the display's real refresh rate,
advancing by actual elapsed time per frame so a dropped frame doesn't
silently slow the read down.

**READABILITY - focus band, narrower column, countdown, practice mode.**
- A `ShaderMask` gradient fades the text toward the top and bottom edges,
  leaving the brightest line at a fixed spot on screen with small muted
  edge arrows marking it. This is the main thing broadcast teleprompters
  do that plain scrolling text doesn't - the eye rests at one place
  instead of chasing a moving line.
- Text column capped at 620px wide and vertically padded 140px at both
  ends, so the first line starts at the reading band instead of jammed at
  the top and the last line can actually reach it.
- 3-2-1 countdown overlay after starting, before the text begins moving
  (recording captures the whole time - a beat of room tone at the head is
  harmless). Same reasoning as round 23's Read Scripture start delay.
- New **"Practice (no recording)"** button on the idle screen once a
  passage is loaded - runs the full teleprompter with nothing recorded, so
  a speed can be dialed in without spending a real take. Header reads
  "PRACTICE - not recording" in blue, and the stop button becomes "Done
  Practicing".
- A "Scroll paused - tap to resume" pill now appears when paused (the old
  tap-to-pause gave no visual confirmation at all).

**Today's Notes - grouped by book, then time.** `todays_notes_screen.dart`
now sub-groups each day's notes by book/file under a book header (with a
per-book note count and a per-book export button), books ordered in normal
**Bible order** via the existing `BibleTextService.findBookId()` +
`bookOrder` (non-scripture titles sort after, alphabetically). Notes run
oldest-first inside a book since that follows how the sitting actually
went. An app bar toggle switches back to the original flat
newest-first-by-time view, so nothing was taken away. Also added
`_exportBook()` - export just one book's notes from one day.

**Not build-tested** - this is a big round, please rebuild and check:
teleprompter still starts/stops cleanly, the countdown appears then text
moves, speed chips + slider both work and changing text size no longer
changes how fast you have to read, the faded top/bottom band looks right,
Practice runs without creating a recording, the screen no longer sleeps
during a long take, and Today's Notes groups by book with the toggle
flipping back to time order.

## Discussed, not built (round 27 fresh-eyes review)

Suggested to the user, no decision yet:
- **Voice-following scroll** (the real "pro" feature): use on-device
  speech recognition to track where you actually are in the text and match
  scroll position to your voice, instead of a fixed pace. Whisper is
  already in the app but is batch, not streaming - this would need a
  streaming recognizer and is a substantial build.
- **Punctuation-derived micro-pauses**: briefly ease the scroll at
  sentence ends using the punctuation already in the text - no AI, no
  network, complements the round-26 AI emphasis marks.
- **Extracting the teleprompter into its own widget file**:
  `record_reading_screen.dart` is now ~1200 lines doing recorder +
  teleprompter + AI emphasis + save dialog. Deliberately NOT done, since
  the standing priority is minimal rework/risk to a working app - noted
  only as the obvious next refactor if this screen keeps growing.
- **Per-passage saved settings**: remember wpm/font per saved passage.

## NEW (round 26): "Analyze for Emphasis" - optional AI delivery tips in the teleprompter

The first feature in this app that talks to a cloud AI - deliberately
scoped tight and off by default. User asked for "intelligent pauses" that
predict good emphasis/pause points, explicitly requiring it can NEVER
change the actual wording (this matters most for scripture), and pointed
out the teleprompter is realistically only used stationary/connected
anyway (not while driving), so a network dependency here is fine even
though the rest of the app stays fully offline.

**New files:**
- `lib/services/settings_service.dart` - tiny local JSON file
  (`settings.json` in the app's documents dir, same pattern as
  SimpleStorage) holding just one thing so far: an optional Anthropic API
  key. Never sent anywhere except directly to Anthropic's API.
- `lib/services/emphasis_service.dart` - `EmphasisService.analyze(chunks,
  apiKey)` sends the loaded teleprompter text to Claude
  (`claude-haiku-4-5` - cheapest/fastest tier, confirmed current via
  Anthropic's docs 2026-08-18) using `dart:io HttpClient` directly (no new
  pubspec dependency - same approach `bible_text_service.dart` already
  uses for its own fetches). Returns `EmphasisMark{chunkIndex, phrase,
  type}` where `type` is `'emphasis'` or `'pause'`.
  - **The actual safety guarantee, not just a prompt asking nicely**: every
    mark's `phrase` is verified as an exact, case-sensitive substring of
    that chunk's ORIGINAL text before it's accepted - anything that isn't
    a verbatim match is silently dropped. The system prompt also
    explicitly forbids rewriting/correcting/paraphrasing. Rendering-side,
    the AI's response is only ever used to decide where to add bold
    styling or insert a small "·" pause glyph around text that's already
    there - it never replaces or retypes any of the original text, so
    there's no code path where the wording on screen could change.

**`record_reading_screen.dart` changes:**
- Once a teleprompter passage is loaded (idle screen), a new "Analyze for
  Emphasis (AI, optional)" button appears under the "Teleprompter ready"
  chip, plus a small key icon to set/change/clear the saved API key.
- First tap with no key saved shows a one-time explainer dialog (what it
  does, that it needs an Anthropic API key from console.anthropic.com,
  rough cost - a chapter-sized passage is well under a penny at Haiku
  pricing) with a field to paste the key; saved locally from then on.
- While recording, emphasis words render bold in a gold/amber accent
  color; suggested pause points get a small muted "·" inserted after the
  phrase. If nothing's been analyzed (or analysis is skipped/fails), the
  teleprompter renders exactly as it did before this round - fully
  additive, same as the teleprompter feature itself.
- Emphasis marks clear alongside the teleprompter passage (on Remove, and
  after a successful save) - not on Discard.

**Not build-tested** - this is the riskiest change so far (first real
network call outside BibleTextService, first raw HTTP POST with headers in
the app) - please rebuild and check closely: the "Analyze for Emphasis"
button appears once a passage is loaded, tapping it with no key saved
prompts for one, a valid key returns suggestions and shows bold/"·"
styling while recording, an invalid key or no internet shows a clear error
(not a crash), and the key icon lets you update or clear a saved key.
Also worth double-checking: the actual verse
text displayed never changes regardless of what comes back from the AI -
only styling/the inserted "·" should ever differ.

## NEW (round 25): Teleprompter — bigger default text, extra "Slower" speed, higher font ceiling

Quick follow-up to round 22's teleprompter. `record_reading_screen.dart`:

- Default text size raised 30 -> 36; the +/- text-size buttons now go up to
  64 (was capped at 48).
- Added a 4th speed chip, **"Slower"** (13px/sec, below the existing
  Slow/Normal/Fast at 20/33/52 - all three existing tiers nudged down
  slightly too). The speed-chip row is now horizontally scrollable so a 4th
  chip can never overflow on a narrower screen.

Also discussed but NOT built yet, offered as ideas only (see chat for the
full list) - a fixed "reading line" focus band with dimmed above/below
text (mimics real broadcast teleprompters), a pre-roll countdown before
scrolling starts, a narrower centered text column, and a finer speed
slider instead of fixed steps. None greenlit yet.

**Not build-tested** - please rebuild and check the teleprompter's default
text size looks noticeably bigger, "Slower" shows up as a 4th chip and is
genuinely more comfortable than the old Slow, and the speed-chip row
scrolls instead of overflowing.

## NEW (round 24): CC's book-guessing now recognizes titles with extra words, not just a bare book name

User walked through a real example: an imported MP3 titled "Numbers Chapter
10" got the generic "Is this a Bible passage?" prompt instead of "This
looks like the Book of Numbers" - because `BibleTextService.findBookId()`
only ever matched when the WHOLE cleaned-up title equaled a book name
exactly ("numbers" alone would've matched; "numbers chapter 10" didn't).
Fixed in `lib/services/bible_text_service.dart`: `findBookId()` still tries
the exact match first (fast path), then falls back to a whole-word search
for any known book name appearing anywhere in the title (word-boundary
matching, longest names checked first so e.g. "song of solomon" wins over
a shorter overlap). So "Numbers Chapter 10", "Numbers 10", "Book of
Numbers", etc. all now resolve to Numbers. This directly improves the CC
dialog's guess AND, since "Read Scripture Instead" already jumps straight
to the guessed book's chapter grid (round 17) using the standard BSB
translation by default (round 18), a better guess here means less manual
searching to land on the right book/chapter combo. Only caller is
`player_screen.dart`'s CC dialog - no other call sites affected.

**Not build-tested** - please rebuild, tap CC on a file titled something
like "Numbers Chapter 10" or "Genesis 1", and confirm the dialog now says
"This looks like the Book of Numbers" (etc.) instead of the generic
fallback, and "Read Scripture Instead" lands directly on that book's
chapter grid.

## NEW (round 23): 2-second pause before Read Scripture starts talking

User reported the Read Scripture reader (`tts_player_screen.dart`) starts
reading before the screen has even finished settling into place - not
enough time to get seated/situated before the voice starts. Added a
2-second delay between the screen finishing its load (verses fetched,
loading spinner gone) and playback actually starting -
`await Future.delayed(const Duration(seconds: 2))` right before
`_startPlayback()` in `_init()`, guarded with a `mounted` check. Chapter
prefetching in the background is unaffected (still starts immediately).
Applies both on first opening a book/chapter and after tapping "Try Again"
from an error (both go through `_init()`).

**Not build-tested** - please rebuild and confirm: opening a chapter in
Read Scripture now gives about a 2-second pause (screen fully visible,
verse text on screen) before the voice starts reading.

## NEW (round 22): Optional teleprompter for Record a Reading (scripture OR your own text), plus bulk share

**Teleprompter** - `record_reading_screen.dart` + new
`lib/screens/teleprompter_passage_picker.dart`. Entirely optional - reading
straight into the mic with nothing loaded works exactly as it always has;
this is purely additive.

- New "Add a Teleprompter (optional)" button on the idle screen opens a
  picker that first asks **"Scripture Passage" or "Your Own Text"**:
  - **Scripture Passage** - the original book -> chapter picker (mirrors
    `ReadScriptureScreen`'s pattern, always BSB), pops back with the
    chosen passage.
  - **Your Own Text** (added mid-round, per explicit request - this isn't
    scripture-only, it's meant to double as a general "teaching
    recorder"/podcast-prep tool) - an optional title field plus a big
    paste/type box. Text is split into scrollable chunks on blank lines
    (falls back to one chunk per line, then to a single chunk) so class
    notes/an outline/a lesson script scroll the same way a chapter of
    verses would.
  - Either path hands back a `TeleprompterPassage{label, verses}` -
    `verses` reuses the `BibleVerse` shape purely as a generic "numbered
    text chunk" container for custom text (no real book/chapter behind
    it), so the teleprompter's scrolling/rendering code doesn't need to
    know or care where the text came from. Loading a passage either way
    also auto-fills the "what are you reading" name field if still blank.
- Once loaded, starting to record switches to a dedicated full-screen dark
  teleprompter view instead of the normal recording screen: the passage
  auto-scrolls at a chosen pace (Slow/Normal/Fast chips), tapping the text
  pauses/resumes ONLY the scroll (recording keeps going), plus manual
  nudge-up/nudge-down buttons and a text-size +/- control. Speed changes
  apply immediately mid-scroll (no restart needed).
- Auto-scroll is driven by a plain `Timer.periodic` nudging a
  `ScrollController` - deliberately not word-per-minute-precise, just an
  approximate pacing aid (verse/line numbers shown small/muted next to the
  text so you can find your place either way).
- Teleprompter state clears after a successful save (same as the name
  field already did), but NOT on Discard, so a bad take can be retried
  with the same passage/text still loaded.

**Bulk share** - `library_screen.dart` gained a third action in My MP3s'
select mode: **Share** (alongside Select All/None and Delete) - shares
every currently-selected file in one Android share-sheet action instead of
one at a time. Came from wanting to quickly get several readings out to an
external enhancement tool (see note below) - user was explicit about not
wanting to learn Audacity ("I need easy"); the app's own Share sheet ->
mobile-browser Adobe Podcast (Enhance Speech) is the "easy" path currently
recommended, not an in-app audio editor.

**Not build-tested** - please rebuild and check: the "Scripture Passage" /
"Your Own Text" chooser appears when you tap "Add a Teleprompter", pasting
some multi-paragraph text and tapping "Use This Text" loads it into the
recording screen the same way a chapter does, the back button on both
sub-screens returns to that chooser (not out of the picker entirely),
loading a passage then recording shows the dark scrolling teleprompter,
Stop & Save still works and saves normally, the speed chips and
pause/nudge/font controls all do what they say, and My MP3s' Share button
(select mode) shares multiple files in one action.

## Discussed, not built: in-app AI audio cleanup (noise removal / filler-word removal / feedback)

User asked about the app doing its own background-noise cleanup, deleting
"ums and ahs," and giving delivery suggestions - similar to Adobe
Podcast's Enhance Speech tool. Assessed, not started:

- **Noise cleanup**: recommended against building this in-app. Adobe
  Podcast's Enhance Speech already does this well, for free, with zero
  code - it's a **web-only** tool (confirmed via Adobe's own docs), but
  Enhance Speech specifically also works fine in a mobile browser, so it's
  usable right on the tablet after exporting a file via the app's existing
  Share feature (now including the new bulk-share above) and picking it
  up from Downloads/Drive in Chrome. Matching that quality on-device would
  need a real trained noise-suppression model (something like RNNoise via
  a custom native plugin) for a result that would likely still be worse -
  not a good use of build effort.
- **Filler-word ("um"/"ah") removal**: more plausible in principle since
  Whisper is already in the app, but has two real open questions that
  would need investigating before it's honestly buildable: (1) whether
  `whisper_ggml`'s Dart API can expose word-level timestamps (today's
  captions are segment-level, which usually bundle a filler word in with
  surrounding words - not precise enough to cut just the filler), and (2)
  what's actually available for audio splicing/re-encoding on Android via
  Flutter today (this needs real investigation, not an assumption -
  ffmpeg-based Flutter plugins have had licensing/maintenance churn).
- **AI delivery suggestions**: a categorically different kind of feature -
  it would need calling an actual LLM API, which means adding a network/
  cloud dependency to an app that is currently 100% offline/local (a point
  celebrated repeatedly - see the "Data model / storage" note below). Also
  too vague yet to build ("suggestions... I don't know what's beneficial")
  - would need real product definition first (pacing? clarity? structure?
  cross-references?).

None of these were built. If revisited, start with the filler-word removal
investigation (points 1-2 above) since it's the most novel and most
buildable of the three, and would benefit from a dedicated feasibility
pass before committing to it - same spirit as the Android Auto build plan.

## NEW (round 21): "Today's Notes" cross-book view + export, plus UI polish feedback

User's scenario: record a note in Daniel, another later in Jeremiah, come
home and want to pull them together without remembering which book each
lived in. New screen, `lib/screens/todays_notes_screen.dart`:

- Every Note from every book/file, joined across `notes.json` ->
  `sessions.json` -> `audio_files.json` (a Note has no direct link to its
  AudioFile - see the data model note below), grouped by day (Today /
  Yesterday / date), newest first.
- Each note shows which book/file it's from, its caption context (real
  chapter:verse if it's a scripture note, the spoken/caption text
  otherwise), the time it was taken, and the note text itself. Tapping a
  note opens that book/file's Sessions screen.
- **Export All** (app bar icon, top right) - every note currently shown,
  combined into one text file grouped by day, shared via the normal
  Android share sheet.
- **Export this note** (icon on each note) - exports just that one note as
  its own text file. Filename follows the same pattern used everywhere
  else in the app (title + reference + when it was taken) - new
  `ExportService.safeNoteFileName()`/`singleNoteText()`/`allNotesDigest()`,
  plus a new `NoteWithSource` helper class pairing a Note with which
  AudioFile it came from (a Note alone doesn't carry that context - see
  `HANDOFF_STUDY_GUIDE_INTEGRATION.md` §3 for the same join explained for
  the study-guide-planner integration).
- Reached via a small `FloatingActionButton.extended` ("Today's Notes") at
  the bottom of the Home screen - deliberately NOT a fourth big button,
  per explicit request to keep the three-big-button layout untouched.

**Follow-up polish requested in the same round, also built:**
- My MP3s' app bar actions (Select / New Folder / Select All / Delete)
  were bare icon-only buttons with only a tooltip - user said they weren't
  clear what they did. New `_labeledAppBarAction()` helper in
  `library_screen.dart` gives each one a bigger icon plus a visible text
  label underneath (mirrors the existing `_labeledIconButton()` pattern
  used on the player screens). "Select All" now also relabels itself to
  "Select None" once everything visible is already selected, matching
  what the button actually does at that moment.
- The Today's Notes button started as a top-right app bar icon; user asked
  for it smaller and floating at the bottom instead - moved to the FAB
  described above.

**Not build-tested** - please rebuild and check: the floating "Today's
Notes" button on Home, that notes from different books show up together
correctly grouped by day, both export flows (all-at-once and one note at a
time - check the exported file names look right), and that My MP3s' app
bar buttons are readably labeled now on the tablet's screen width.

## Still open: no in-app "delete everything and start fresh" button

Asked about this in round 21 - there's no in-app reset feature (no
Settings screen exists yet at all). The already-available way to fully
wipe this app's data today is Android's own **Settings -> Apps -> Commute
Notes -> Storage -> Clear storage/Clear data** - since everything (JSON
files, recordings, voice notes, imported audio, Bible cache) lives in this
app's private documents directory (see `HANDOFF_STUDY_GUIDE_INTEGRATION.md`
§2), that one Android-level action wipes all of it cleanly, no reinstall
needed. Not built as an in-app button since Android already does this
natively - could add one later (a Settings screen doesn't exist yet
either) if it turns out to be wanted often enough to be worth the trip to
Android's own settings.

## NEW (round 20): Transport row reordered - Stop / Record Note / Play, Stop now true red

Follow-up to round 19's bigger "Record Note" button - user tested the MP3
player (hasn't looked at the Read Scripture reader yet) and wanted the
positions changed too, not just the size. Applied to both
`player_screen.dart` and `tts_player_screen.dart`:

- Row order changed from Record Note / Stop / Play to **Stop / Record Note
  / Play** - Record Note is now centered (and still the biggest of the
  three), Stop moved to the left.
- Stop's color changed from `theme.colorScheme.error` (a theme-dependent
  color that can render as a muted/dark red) to an explicit true red
  (`0xFFD32F2F`), so it reads unambiguously as "stop" regardless of theme.
- Play unchanged - still green, still on the right.

**Not build-tested** - please rebuild and check both the MP3 player and
the Read Scripture reader (user has only seen the MP3 player so far).

## NEW (round 19): Bigger "Record Note" button (was "Pause") on both player screens

User sent a Paint-marked-up screenshot of the Read Scripture player showing
the middle button enlarged and relabeled - it's the button they use most
(pausing playback/reading also starts recording a voice note, so
functionally it already was "the record button"). Applied to both
`tts_player_screen.dart` and `player_screen.dart` (same shared
`_labeledIconButton()` pattern, kept in sync):

- Label changed from **"Pause"** to **"Record Note"** on the middle button
  (icon unchanged - still the pause icon, since it still pauses playback,
  it just also starts recording the moment you tap it, same as before).
- Sizing: that button is now the biggest of the three (was 92px/98px/92px
  for Pause/Stop/Play - Stop used to be the largest; now Record Note is
  112px, Stop and Play are both 88px).
- No behavior change - purely label + sizing, same `_pauseAndRecord()`
  method as always.

**Not build-tested** - please rebuild and confirm the middle button on both
the MP3 player and Read Scripture reader looks noticeably bigger than
Stop/Play and says "Record Note", and that everything still fits/doesn't
overflow at that size on the tablet's screen width.

## NEW (round 18): "Caption with Real Text" - keep the MP3's own voice, caption it with real scripture text

Follow-up to round 17. User's concern: "Read Scripture Instead" throws away
the original recording's voice entirely (switches to synthetic TTS) - but
sometimes the person reading the MP3 has a really nice voice worth keeping,
and Whisper transcription ("Transcribe Anyway") is the only way to keep
that voice, at the cost of a long wait. This adds a third middle-ground
option to the same big-file warning dialog (`player_screen.dart`'s
`_confirmSlowCaptionRun()` / `_generateCaptions()`), shown only when a book
was guessed from the title:

- **"Caption with Real Text"** - keeps the MP3 playing exactly as recorded
  (same human voice), but instead of running slow Whisper transcription, it
  pulls the real Berean Standard Bible (BSB) text for the chapter(s) you
  pick and displays that as captions.
- User explicitly said: don't bother with a translation picker, just always
  use BSB, and it's fine if it doesn't exactly match whatever translation
  the reader on the MP3 is actually reading from.
- Since there's no way to know exactly when a given reader says each verse,
  timing is **estimated**: each verse gets a slice of the file's total
  duration proportional to its word count (a short verse like "Jesus
  wept." gets a short slice), laid end-to-end. New method
  `_buildProportionalSegments()` in `player_screen.dart`. Not a real
  transcript - captions will drift somewhat, especially over a long
  chapter, but should stay roughly in the neighborhood without any wait.
- New small dialog `_pickChapterRange()` asks which chapter(s) the
  recording covers (title only tells us the book) - two dropdowns,
  "Starting chapter" / "Through chapter", defaulting to chapter 1 only;
  bumping the start up also bumps the end up to match.
- Reuses the exact same caption storage/display pipeline as Whisper
  (`TranscriptService.save()`, `TranscriptSegment`) - so playback, the
  scrolling caption UI, everything downstream just works unchanged.
- The dialog's explanatory text was also updated to make the tradeoff
  explicit: "Read Scripture Instead" now says outright that it uses a
  computer voice instead of the recording's own narrator, and (when a book
  was guessed) a new italic line explains what "Caption with Real Text"
  does differently.

**Not build-tested** - please rebuild, open My MP3s, tap CC on a file whose
title looks like a Bible book, and confirm: the dialog now shows a third
"Caption with Real Text" button, tapping it prompts for a chapter range,
and after picking one the file keeps playing with its own audio while
captions show the real BSB verse text (roughly, not perfectly, in sync).

## NEW (round 17): "Is this scripture?" prompt before transcribing, with a one-tap redirect

Follow-up to the long-Whisper-run discussion - instead of (or alongside)
building real cancel/chunking for Whisper, the big-file warning dialog on
My MP3s (`player_screen.dart`'s `_confirmSlowCaptionRun()`, shown when you
tap CC) now actively offers to skip transcription entirely when the file
looks like scripture:

- Reuses an existing-but-previously-unused helper,
  `BibleTextService.findBookId()`, to guess a Bible book from the file's
  title (handles things like "02_Exodus", "John", "1st_Corinthians").
- New `BibleTextService.bookNameForId()` - reverse lookup from a guessed
  id back to a display name.
- The dialog now shows a highlighted callout: "This looks like the Book
  of [X]" (or "Is this a Bible passage?" if nothing matched) plus a new
  **"Read Scripture Instead"** (or "Choose Scripture" if no guess) button
  alongside the existing Cancel / Transcribe Anyway options.
- `ReadScriptureScreen` gained an optional `initialBook` constructor
  param - when set, `initState()` calls `_selectBook()` immediately,
  skipping the book list and landing straight on that book's chapter
  grid. Tapping "Read Scripture Instead" passes the guessed name through;
  if nothing was guessed, it still opens Read Scripture, just at the book
  list instead of jumping anywhere.

**Known limits (told to user):** only works when the file's title/filename
actually resembles a book name - a generic title like "Track 5" won't
match, so the button just opens the manual book picker instead of a dead
end. It can only guess the *book*, not a specific chapter (most filenames
don't encode that). This does NOT address the underlying "no cancel
button" gap for genuinely non-scripture long files (sermons, personal
recordings) - see the note below for what would actually fix that.

**Not build-tested** - please rebuild, open My MP3s, tap CC on a file
titled something recognizable (e.g. rename a test file to "John" or
"02_Exodus" first if needed), and confirm: the dialog shows the guessed
book name, tapping "Read Scripture Instead" jumps straight to that book's
chapter grid (not the book list), and tapping CC on a file with an
unrecognizable title still shows the dialog with a generic "Choose
Scripture" button that opens Read Scripture at the book list.

## Still open: long Whisper caption runs have no true cancel button

Discussed with user (not yet built, no decision made to build it yet):
`whisper_ggml` doesn't expose a way to interrupt a run in progress, which
is the actual reason there's no cancel button today - `wakelock_plus`
just keeps the screen/CPU awake, it doesn't help with cancellation.

Real fix, if/when wanted: **chunk the transcription** - split the source
audio into e.g. 5-10 minute pieces, transcribe sequentially, check a
"cancel requested" flag between chunks (bounds the wait-to-cancel to one
chunk instead of the whole file), and save each chunk's captions to disk
as it finishes (so a kill/crash partway through only loses the current
chunk, and a run could resume instead of restarting from zero). A
secondary, independent improvement would be a proper Android foreground
service with a progress notification, so the OS is less likely to kill
the app under memory pressure - bigger change, a native plugin like
`flutter_foreground_task`. Round 17's "read scripture instead" prompt
(above) sidesteps this for anything that actually is scripture, but
doesn't solve it for real long-form non-scripture recordings.

## ✅ CONFIRMED FIXED: Pause now correctly starts recording a voice note

User tested on the MP3 player after the round-11 permission-dialog fix:
"when you hit pause, it pops up and starts recording like it's supposed
to." Root cause was the microphone permission (Android silently refusing
to re-prompt after an earlier denial) - the `AlertDialog` + "Open
Settings" fix in `_startRecordingNote()` (both `player_screen.dart` and
`tts_player_screen.dart`) resolved it. No further action needed here
unless it resurfaces.

## Awaiting user test - everything built this session (rounds 12-16, 18)

User is testing progressively and reporting back as they go. Confirmed
working so far: recording + captioning (round-13-era flow), the "Share /
save audio file" option showing up in My MP3s (round 13), and the Pause
fix above (round 11). Still unconfirmed:

- **Round 18** - "Caption with Real Text" option (see above) - keeps the
  MP3's own voice, captions with real BSB text, estimated per-verse timing.
- **Round 16** - naming a reading BEFORE recording (`record_reading_screen.dart`):
  text field above Start Recording, combines typed name + timestamp into
  the title, shown while recording, clears after save, screen now
  scrollable for the keyboard.
- **Round 15** - My MP3s folder cards default collapsed, auto-expand while
  searching, new "Folders:" sort dropdown (Name A-Z / Most files /
  Recently added).
- **Round 14** - My MP3s search box, "Files:" sort dropdown (Newest/
  Oldest/Title A-Z/Longest), "Select" mode for multi-file delete.
- **Round 12** - Sessions screen: `_defaultLabel()` now includes a
  timestamp, not just a date; Sessions list shows the actual caption text
  at each session's last position instead of a bare time.
- **Round 11 (button styling)** - colors + labels on Pause/Stop/Play and
  the secondary buttons (Mute, Type Note) on both player screens; check
  nothing overflows/wraps oddly on the tablet's screen width.

## Known still-open item (lower priority)

- Long Whisper caption runs (3+ hours) still have no true cancel button
  except force-closing the app - not a blocker, just a known limitation.
  Prefer Read Scripture (TTS) over importing very long MP3s when possible.

---

## Quick reference

**Always build/run in release mode for real use:**
```text
C:\src\flutter\bin\flutter.bat run --release -d R52YA02836J
```
Debug mode is dramatically slower for Whisper and can make the UI look
frozen during transcription.

**PC setup (already done on user's machine):**
- Flutter 3.47.0 at `C:\src\flutter`; project at `C:\src\commute_notes`
- Tab S10 connected/authorized: device id `R52YA02836J` (SM-X520, Android 16)
- Tablet must be in File Transfer/MTP mode, not Charging only, with USB
  debugging + "Allow" accepted
- If `flutter` isn't on PATH: `cmd /c "C:\src\flutter\bin\flutter.bat ..."`
- `run_app.bat` in the project folder is a debug-mode double-click
  shortcut; use the release command above for real use instead

**Files that matter most:**
- `pubspec.yaml` — dependencies (`whisper_ggml`, `record`, `flutter_tts`,
  `share_plus` pinned to `^12.0.2`, `permission_handler`)
- `lib/screens/home_screen.dart` — app home, 3 big buttons
- `lib/screens/read_scripture_screen.dart` — book → chapter-grid picker
- `lib/screens/tts_player_screen.dart` — TTS reader, pause-to-record notes
- `lib/services/bible_text_service.dart` — fetches/caches real verse text
- `lib/screens/player_screen.dart` — MP3 playback, pause-to-record notes,
  typed notes, CC button
- `lib/screens/library_screen.dart` — My MP3s: collections, search, sort,
  multi-select delete, per-file share/rename/delete
- `lib/screens/record_reading_screen.dart` — standalone long-form
  recorder, name-before-recording, saves into a collection
- `lib/screens/sessions_screen.dart` — session list, timestamped names,
  caption-context subtitles
- `lib/services/export_service.dart` — notes text export + audio filename
  helper for sharing
- `lib/models/models.dart` — AudioFile (collection, lastChapter/lastVerse),
  Session, Note
- `lib/services/transcript_service.dart` — Whisper transcription (captions
  + voice notes) + JSON storage
- `lib/services/voice_recorder_service.dart` — wrapper around `record`
- `lib/services/audio_player_service.dart` — playback + call interrupt

**Known device notes:**
- Microphone permission is requested the first time a voice note is
  recorded; if denied once, Android may not auto-re-prompt - the
  "Open Settings" dialog (round 11) covers this now.
- The TTS reader needs internet the first time it fetches a given
  chapter; after that it's cached to disk (`bible_cache/`) and works
  fully offline.
