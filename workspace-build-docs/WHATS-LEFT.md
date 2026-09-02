# What's Left — Consolidated Status (as of Living Waters v1.0)

One place pulling together every open item tracked across `build-tracker.md`,
`bible-commentary-master-tracker.md`, `lib/LIVING-WATERS-CHECKLIST.md`, and
`MASTER-PROMPTS.md`. Bring this file alone to get oriented; the individual
trackers still hold the full detail/methodology behind each line.

---

## 1. Living Waters rebrand — VISUAL ROLLOUT COMPLETE

**Done:** Homepage (full treatment). All 6 section indexes. All 21 book-level pages. All 3
topical modules (Parables, Messianic Prophecy, Millennial Kingdom). Doctrine's Church History
page. All 6 deep-dive commentary pages. **All 55 individual chapter/room pages** across every
book — Genesis, Matthew, John, Jude, Philemon, and all 15 OT prophet books.

**102 pages converted total. Nothing site-wide is left on the old look** except Thought
Organizer, Apocrypha's `coming-soon.html` template, and Commute Companion (intentionally
excluded — needs to stay offline-safe).

**Still open, low priority:**
- [ ] Thought Organizer
- [ ] Apocrypha's `coming-soon.html` template page
- [ ] 6 local photo slots still waiting on real files from you (`data/photos/local-01.jpg`
      through `local-06.jpg`)
- [ ] Decision on whether Commute Companion ever gets a visual refresh (current call: stays
      as-is permanently, needs offline safety)

**Note on the 15 OT prophet book pages:** these got a lighter-touch conversion for their
book-level index pages — outer navigation chrome swapped, but profile cards/Hebrew word-chip
bars/comparison tables left on their original (still fully functional) styling, since a
pre-existing gap was found in their reader-tools code (CSS/JS present, no matching HTML
elements — not introduced or fixed here). Their individual chapter room pages, by contrast,
got the full standard conversion like everything else. Genesis and Matthew's book-level pages
got the deeper full-content treatment throughout.

**Historical Development expansion — COMPLETE.** `topics/` moved+renamed to
`scripture-studies/topical-studies/` (zero broken links). New 4th topical module Prophecy
(index + 3 rooms). `doctrine/bible-history/` (OT + NT canonization pages). `doctrine/denominations/`
(comparative matrix hub + all 10 individual deep-dive pages). 17 new/moved pages, full site
smoke test clean throughout.

## 2. NT Commentary Project — Matthew 1 of 28 chapters done

Order: Matthew → Mark → Luke → John → Acts → Romans. Revelation already complete
(22 chapters, done in an earlier session). Methodology locked in (verse-by-verse,
Scripture-explains-Scripture, 5-tradition differences-only, verified commentators,
Early Church/Apocrypha context layer) — this is the standard for all of Phase 1 now.

**Left in Matthew (28 chapters total):**
- [ ] Revise to new standard: chapters 2, 3, 5, 6, 16, 26, 27, 28 (exist in old
      6-tradition/stub format)
- [ ] Build from scratch: chapters 4, 7–15, 17–25 (19 chapters)

**Left after Matthew:**
- [ ] Mark (16 chapters) — not started
- [ ] Luke (24 chapters) — not started
- [ ] John (21 chapters) — 2 chapters exist in the OLD hybrid model (1, 6), need the
      same revision Matthew's old chapters need, plus 19 more to build
- [ ] Acts (28 chapters) — not started
- [ ] Romans (16 chapters) — not started
- [ ] Remaining 21 NT books (1–2 Corinthians through Jude) — not started, order TBD
      after Romans
- [ ] Old Testament, all 39 books — queued, not started (Phase 2)

## 3. Illuminated Redesign — superseded by Living Waters

This was the active project before the Living Waters pivot. Its remaining ~103 pages
are the same pages listed under section 1 above — Living Waters is now the target
design, not the old illuminated system. `lib/CONVERSION-CHECKLIST.md` (illuminated)
is effectively retired in favor of `lib/LIVING-WATERS-CHECKLIST.md`.

## 4. Topical Suite — 2 of 6 topics done, untouched this session

**Done:** Election/Predestination, Sacraments/Ordinances.
**Left:**
- [ ] Spiritual Warfare
- [ ] Covenant Theology
- [ ] Eschatology (link to the existing Millennial Kingdom module rather than duplicate)
- [ ] Ethics

## 5. Small Group Curriculum — tool built, no real curriculum written yet

The Small Group Curriculum Builder tool is live and working (`tools/sermon-builder.html`
section 4). What's still missing is actual content: no real study is currently running
(confirmed — you're doing individual Revelation study + Bible in a Year right now, no
4x/week group), so there's nothing to build with it yet. Whenever a real group study
exists, the tool + Reading Plan Builder are both ready to receive it.

## 6. Sermon Builder — still a prompt-assembler, not a generator

Only the new Small Group Curriculum Builder section got upgraded to real `/api/chat`
generation this session. The original Sermon Builder (section 3 of the page) still just
assembles a prompt for you to run through an AI elsewhere — matching it to the
Curriculum Builder's real-generation approach is a real, not-yet-requested upgrade.

## 7. Smaller standing items — untouched this session

- [ ] Fix Prompt 4's period color table to match the real Jeff Cavins 12-period scheme
      (currently uses an invented one)
- [ ] Resolve which "Armstrong" was meant for the Source & Perspective Engine's default
      commentator preset (flagged back in Prompt 12, never answered)

---

## Quick-reference: what's actually fully finished and stable
- Site/Commute Companion merge, unified plan system, journal + archive
- Reading Plan Builder (manual entry, AI file import, Curriculum Builder handoff)
- Revelation full commentary (22 chapters) — old chapter-level format, not yet
  converted to the new verse-by-verse standard, but complete as originally scoped
- Genesis (7 chapter groupings), the 16 OT prophet books, Parables module (3 rooms),
  Church History & Doctrinal Development room, Millennial Kingdom module — all
  built in earlier sessions, still on the old illuminated design, functionally complete
