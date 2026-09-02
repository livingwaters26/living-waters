# Library hierarchy — agreed design (not yet built)

**Written:** 2026-08-19 (round 30)
**Status:** design agreed in principle, nothing built yet - saved here as a
backup so this doesn't have to be re-derived from scratch in a future
session. User wants to live with the current flat-collection library a
while longer before committing to this rebuild ("I'd have to use it to
make sure").

---

## The problem this solves

The current library is flat: every AudioFile has one `collection` string
(a single folder name), and a Session belongs to exactly one AudioFile.
That's fine for a handful of files, but breaks down once you're juggling
multiple translations, multiple narrators per translation, and multiple
chapter-files per book - it turns into one long list, and there's no way
to browse "everything Narrator A has read in BSB" as a group. On top of
that, trying a second captioning method (Whisper CC, then "Caption with
Real Text") on the same file today silently overwrites the first
transcript instead of keeping both, which was producing confusing
duplicate sessions (see round 30 notes in `commute_notes.md` / project
memory for the full diagnosis).

## The agreed shape

A multi-level browsable tree, modeled on how Windows Explorer actually
works under the hood: a file doesn't really "live inside" a folder, it
just carries a path, and Explorer builds the tree you see by grouping
files that share a path prefix. Same idea here - a recording carries a
few tags (translation, narrator, book), and the app builds the tree from
those tags. Nothing is a real nested folder on disk; it's a display built
from metadata, same as it is now (today's single `collection` string is
just replaced by two or three).

```
My Library
├─ Bible Translations
│  ├─ BSB
│  │  ├─ Narrator A
│  │  │  ├─ Genesis
│  │  │  │  ├─ Genesis 1-20.mp3
│  │  │  │  │  ├─ Session: 8/15 3:15 PM   (4 notes)
│  │  │  │  │  └─ Session: 8/17 9:02 AM   (2 notes)
│  │  │  │  └─ Genesis 21-50.mp3
│  │  │  │     └─ Session: 8/18 6:40 AM
│  │  │  └─ Matthew
│  │  │     └─ Matthew.mp3
│  │  │        └─ Session: 8/16 ...
│  │  └─ Narrator B
│  ├─ ESV
│  ├─ KJV
│  └─ NIV
├─ Personal Readings / Sermons   (no translation/narrator - stands alone,
│                                  same as today's "Personal Readings")
├─ Continue your notes           (shortcut - ALREADY BUILT, round 30)
└─ Recent sessions               (shortcut - proposed, NOT built)
```

### Confirmed decisions

- **A book folder (e.g. Genesis) can hold one file or several** - the
  Psalms 1-20 / 21-52 split fits naturally as two files under one Genesis
  (well, Psalms) node, no special case needed.
- **Sessions live under the file, notes live under the session** - this
  is exactly today's existing data model (AudioFile 1:many Session 1:many
  Note) and does NOT need to change. What's new is only the browsing
  layers ABOVE the file (translation → narrator → book), replacing
  today's single flat `collection` tag.
- **Notes are not relocated anywhere** - a note still always knows exactly
  which session/file/timestamp it came from, same as today, so jumping
  back to the exact second still works.
- **Root-level shortcuts bypass the tree entirely** - "Continue your
  notes" (built) and "Recent sessions" (not built) are fast doors straight
  to a deep session, the same way a pinned shortcut in Explorer doesn't
  require navigating the real folder path by hand.
- **Every level needs an explicit "+ New" action** - add a new translation
  at the top, add a new narrator inside a translation, add a new
  book/chapter inside a narrator - same idea as right-click → New Folder,
  just typing a new tag value on the spot rather than creating a physical
  folder. Should work both ahead of time (pre-create an empty category)
  and inline while importing a file (today's "+ New collection" pattern,
  generalized to 3 fields instead of 1).

### Resolved (round 30, later)

- **CC vs "Text from scripture" as two coexisting caption sets - RESOLVED
  and BUILT.** User confirmed the toggle approach ("i like the toggle it
  saves adding files") over separate folder nodes. `transcript_service.dart`
  now stores both caption sets per file (`{"whisper": [...], "scripture":
  [...]}`); `AudioFile.activeCaptionKind` tracks which is showing; a real
  toggle (two chips) appears in `player_screen.dart` once both exist. This
  was the fix for the round-30 overwrite bug (only one transcript ever
  saved per file before this). See `NEXT_SESSION.md` for the full
  build notes.

### Still open / NOT confirmed
- **Non-Bible content placement** - "Personal Readings / Sermons" sitting
  outside the Bible Translations branch was suggested, not explicitly
  confirmed.
- **Exact UI mechanics** of the tree browser itself (expand/collapse
  behavior, how deep to default-expand, whether this replaces
  `library_screen.dart` entirely or is a new screen alongside it) -
  not designed yet at all, purely conceptual so far.

## What this actually requires to build (rough scope, not estimated)

- `AudioFile` needs translation/narrator/book as separate fields (or a
  more general small hierarchical tag system) instead of the single
  `collection` string it has today. Migration path for existing files
  (today's flat collections, e.g. "Personal Readings") needs thought - they
  shouldn't just disappear or need re-tagging by hand.
- A genuinely new tree-browsing UI in `library_screen.dart` (or a
  replacement screen) - a bigger rewrite than any single addition made in
  round 30.
- The "+ New" affordance at each level.
- ~~Resolving the CC/Text-from-scripture question above before touching
  `transcript_service.dart`'s current one-transcript-per-file storage.~~
  Done - see "Resolved" section above.
- A "Recent sessions" shortcut (structurally similar to round 30's
  "Continue your notes," just unfiltered by notes and probably showing
  more entries).

## Next step, whenever this comes back up

Don't start with the data model change. Start by confirming the CC/Text-
from-scripture question, then a rough mockup/description of the tree
screen itself, before touching `AudioFile` or any storage code - this is
a big enough change that jumping straight to code risks a lot of rework if
the browsing details turn out to feel wrong once actually used.
