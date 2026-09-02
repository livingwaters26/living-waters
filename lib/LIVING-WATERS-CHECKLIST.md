# Living Waters Rollout — Checklist

Homepage (`index.html`) is the flagship, already built with the full treatment (photo
backdrop, dawn horizon, live ticker, rotating insight carousel). Everything below it
gets the same top bar (ticker + logo + back-to-hub link) and `lw-section-card` grid
styling for navigation pages — the photo backdrop/horizon are homepage-only for now,
to keep subpages lighter.

**Pattern for converting a section-index page** (confirmed working on Topics and
Doctrine): add the Tailwind/FontAwesome/Google Fonts CDN links + `lib/living-waters.css`
to `<head>` right after the existing `hub-ui.css` link. Then replace only the
`<body>` → `<div class="container">` → header/grid block with the Living Waters
header + `lw-section-grid`/`lw-section-card` markup, stopping right before
`<div class="rt-toolbar" id="rtToolbar">` — leave everything from there down
(the reader-tools highlight/note/verse-modal apparatus) completely untouched.
Don't touch the old `.container`/`.grid`/`.card` CSS rules in the `<style>` block
either — they just go unused, harmless dead CSS, not worth the risk of editing
around the reader-tools styles that share the same block.

## A. Section Indexes (6)
- [x] `topics/index.html` — done this session (4 cards)
- [x] `doctrine/index.html` — done this session (6 cards)
- [x] `apocrypha/index.html` — done this session (9 book cards + history-note + framing-note callouts, all real content preserved)
- [x] `commentary/index.html` — done this session (6 book cards + full Tools list; no reader-tools apparatus on this page, so it got a full rewrite rather than a surgical block-swap)
- [x] `scripture-studies/old-testament/index.html` — done, all 39 book entries across 5 groupings (generated programmatically from extracted card data to avoid transcription errors, then verified every link — built-book links as `<a>`, coming-soon as inert `<div>`)
- [x] `scripture-studies/new-testament/index.html` — done, all 27 book entries across 5 groupings, same method — **Section A now fully complete, all 6 section indexes converted**

## B. Everything else (same ~100 pages the old Illuminated checklist tracked)
Not yet inventoried against the Living Waters pattern specifically. The old
`lib/CONVERSION-CHECKLIST.md` (Illuminated system) has the full page-by-page list
if a straight mapping is wanted — most of those same pages need the equivalent
Living Waters treatment. Recommend: finish the book-level index pages next (below),
then the individual chapter/room pages, same order the Illuminated rollout used:
Parables → Messianic Prophecy → Millennial Kingdom → Church History → everything else.

### B1. Book-level index pages (21 total: 5 NT + 16 OT)
Two patterns found — some (like Genesis) have no reader-tools apparatus and get a
full rewrite; others (Matthew, Obadiah, John, and likely most of the rest) carry the
same rt-toolbar apparatus as the section indexes and need the same surgical
header/grid-only swap, not a full rewrite. Check for `rt-toolbar` before choosing
which approach per page.
- [x] `scripture-studies/old-testament/genesis/index.html` — done (no reader-tools, full rewrite; author-profile card + 7 chapter-grouping cards)
- [x] NT: `matthew/index.html` (surgical, 28-chapter grid generated programmatically), `john/index.html` (full rewrite), `jude/index.html` (full rewrite), `philemon/index.html` (full rewrite), `revelation/index.html` (surgical; added a link to the existing Commentary Deep Dive since this room's own chapters aren't built yet) — all 5 NT book pages done
- [x] OT: `isaiah/`, `jeremiah/`, `ezekiel/`, `daniel/`, `hosea/`, `joel/`, `amos/`, `jonah/`, `micah/`, `nahum/`, `habakkuk/`, `zephaniah/`, `haggai/`, `zechariah/`, `malachi/` — all 15 done via a batch script (found these OT book pages have reader-tools CSS/JS but no matching HTML toolbar elements — a pre-existing quirk, not something I introduced or fixed; left the CSS/JS as-is either way). Approach here: preserved profile-card, Hebrew word-chip bars, premil/amil/postmil comparison tables, and chapter grids completely byte-for-byte untouched (they still use their own page-level CSS, still fully functional) — only swapped the outer chrome (body/container/top-nav/header → LW backdrop+header+hero, closing tag → `</main>`). Lower-risk and much faster than full inner-content restyle, and the CSS itself was already good/functional, just needed brand-consistent chrome. All 16 books smoke-tested: 200 OK, LIVING WATERS branding present, profile-card intact, div/main tag balance exact on every one.

**Section B1 (all 21 book-level pages) is now fully complete.**

### B2. Individual chapter/room pages
Not started. This is the bulk of the ~100 pages — every `rooms/chNN.html` across
every book, every topical module's sub-pages (Parables, Messianic Prophecy,
Millennial Kingdom), Doctrine's Church History page, all deep-dive commentary
pages, Thought Organizer, and the Apocrypha coming-soon pages.

- [x] **Parables module — fully done** (4 pages): `topics/parables/index.html` (frameworks + consensus badges + 3-card grid, full rewrite) and all 3 rooms — `sower.html`, `prodigal-son.html`, `good-samaritan.html` (full rewrite each, all content preserved: intro-box, tl;dr line, beat/soil-card grids, consensus blocks, cross-ref links). None of these had reader-tools apparatus, so full rewrites were safe. Smoke-tested, exact div/main tag balance on all 4.
- [x] **Messianic Prophecy module — fully done** (6 pages): `topics/messianic-prophecy/index.html` (stat strip + 5-card grid, surgical swap) and all 5 rooms — `birth.html`, `ministry.html`, `passion.html`, `death-burial-resurrection.html`, `reign.html` (surgical swap via batch script, all 38 prophecy/fulfillment comparison cards preserved verbatim, verse-modal and reader-tools untouched). Hit and fixed a real bug here: the batch script's chrome-swap left one orphaned `</div>` per file (the original `.container` div's closing tag, whose opening tag got removed but closing tag was outside the swap range) — found and fixed with a stack-based scanner rather than guessing patterns, since the exact tail structure varied per file. All 6 re-verified with exact div/main balance and confirmed reader-tools/verse-modal functions still present.
- [x] **Millennial Kingdom module — fully done** (4 pages): `topics/millennial-kingdom/index.html` (legend + 3-room grid + all 16 prophet-book chips, full rewrite) and all 3 rooms — `historical-development.html`, `nt-witnesses.html`, `revelation-20.html` (batch script, same pattern as Messianic Prophecy but with the orphaned-closing-div fix built in proactively this time — all 4 pages came out perfectly balanced on the first pass, no separate fix-up step needed).
- [x] **Doctrine's Church History page — done** (`doctrine/church-history.html`, 865 lines, batch script w/ orphan-fix built in — councils/creeds timeline, doctrinal evolution matrix, denominational family tree all preserved).
- [x] **5 of 6 deep-dive commentary pages done** (`genesis-deep-dive.html`, `matthew-deep-dive.html`, `john-deep-dive.html`, `acts-deep-dive.html`, `romans-deep-dive.html`) — these turned out to be fully-written content (author profile, key themes, verse-by-verse insights w/ Hebrew lex notes, historical development, cross-links), not stubs. No reader-tools on these; clean self-contained header swap, verse-by-verse content untouched. **46 pages converted total now.**
- [x] **All 6 deep-dive commentary pages done.** `revelation-deep-dive.html` (last one) reused the illuminated hero/dawn-horizon pattern this page already had — swapped for the Living Waters equivalent (same header+ticker+horizon device as the homepage), kept the pullquote, author profile, chapter jump-nav, and all 22 chapters' content untouched. **47 pages converted total.**
- [x] **ALL 55 individual chapter/room pages done** across every book — Genesis (7), Matthew (9), John (2), Jude (1), Philemon (1), and all 15 OT prophet books (Isaiah, Jeremiah, Ezekiel, Daniel, Hosea, Joel, Amos, Obadiah, Jonah, Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi — 34 pages combined). One master batch script auto-detected template type per file (dark-slate w/ or w/o reader-tools vs. illuminated-style) and converted 53 of 55 in a single pass; the 2 outliers (Genesis ch01, Isaiah ch09 — both early illuminated-prototype pages predating the shared `lib/illuminated.css` convention, one even fully self-contained with inline `<style>` and no external stylesheet link) got individual hand conversion using the same dawn-horizon pattern already proven on the homepage and Revelation deep-dive. Hit the same orphaned-closing-div bug as before on 34 files (all the ones with reader-tools) — fixed with the same stack-based scanner, this time as a bulk cleanup pass across all flagged files at once rather than one at a time. Verified: Matthew ch01's special NT-commentary content (Scripture-explains-Scripture cross-refs, verified-commentator tradition boxes, Early Church extra-note) survived completely intact through the conversion. Hebrew/Greek audio-chip buttons (`onclick="playGreekAudio(...)"` etc.) and their backing functions confirmed intact via targeted checks. Full site-wide smoke test (homepage, every section index, every tool, journal, API) passes clean.

**THE ENTIRE LIVING WATERS VISUAL ROLLOUT IS NOW COMPLETE.** 102 pages converted total (47 from the navigation/module phase + 55 individual room pages). Nothing site-wide is left on the old illuminated or dark-slate look except: Thought Organizer, Apocrypha's `coming-soon.html` template, and Commute Companion (intentionally excluded — must stay offline-safe).
- [ ] Thought Organizer
- [ ] Apocrypha's `coming-soon.html` template page

## Historical Development expansion + topics restructure — MOVE/RENAME DONE

- [x] **`topics/` → `scripture-studies/topical-studies/` — moved and renamed.** Used absolute-path
  resolution rather than pattern-matching: every relative link inside the 15 moved files was
  resolved to an absolute site path using its OLD location, remapped if that target was also
  moving, then re-expressed as a relative path from its NEW location. Same treatment for all 15
  external files that linked into the old `topics/`. Zero broken links found on verification
  (`grep -r "topics/"` site-wide returns nothing outside `topical-studies/`). Also found and fixed
  a real redundancy this surfaced: `scripture-studies/index.html` existed but had never been
  converted to Living Waters (missed in the original inventory) — converted it and added a proper
  Topical Studies card there now that it's a real child section, and removed the now-duplicate
  standalone "Topical Studies" card that was still sitting on the homepage. Full site smoke test
  clean after all of it.
- [x] **New 4th topical module: Prophecy — done.** `scripture-studies/topical-studies/prophecy/index.html` plus 3 rooms: `reading-apocalyptic.html` (genre conventions — symbolic numbers, cosmic/political imagery, why "literal vs. symbolic" is the wrong first question, all four reading strategies explained properly with real historical grounding — e.g. historicism's Reformation-era dominance, full vs. partial preterism's orthodoxy question), `daniel-ezekiel-visions.html` (the four kingdoms, the four beasts, the seventy weeks flagged as genuinely contested rather than glossed over, the valley of dry bones, Gog and Magog, the visionary temple), `olivet-discourse.html` (what the discourse covers section by section, then the "this generation" puzzle laid out as four real live resolutions with no verdict imposed). Added as a card to `scripture-studies/topical-studies/index.html`. Explicitly NOT a duplicate of Millennial Kingdom Prophecy — that module stays focused on kingdom passages verse-by-verse; this one is genre-level and cross-links out to it, to the existing Daniel/Ezekiel book rooms, and to the Revelation Deep Dive rather than repeating any of that content. All 4 pages tag-balance clean, serve-tested, cross-links verified to resolve correctly.
- [x] **`doctrine/bible-history/` — done.** `ot-canonization.html` (Tanakh's threefold structure, Masoretic Text/DSS/Septuagint/Samaritan Pentateuch, the Jamnia overstatement corrected — most scholars now consider it not a single closing council, protocanonical/deuterocanonical comparison table cross-linked to the Apocrypha section) and `nt-canonization.html` (full timeline from Acts 15 through Carthage 397 AD, the Antilegomena six books explained with real historical context — including Luther's actual "epistle of straw" line on James, properly short-quoted — early heresies/schisms that shaped the process, and the Alexandrian/Byzantine/Western textual families as a distinct question from canonization itself). Both added as cards to `doctrine/index.html`. Tag-balance clean (including the OT page's comparison table), serve-tested, cross-links to Apocrypha and Church History verified.
- [x] **`doctrine/denominations/` — done.** `index.html` as a comparative matrix hub (5 categories × 10 traditions in a scrollable table, plus a family-tree callout summarizing the 1054/1517/subsequent splits and cross-linking to Church History for the full depth), then all 10 individual deep-dive pages — Catholicism, Orthodoxy, Anglicanism, Lutheranism, Reformed/Calvinism, Methodism, Baptist, Anabaptism, Pentecostalism, Non-Denominational. Each page: quick-facts profile, a real 2-paragraph historical origin narrative, and 4 core-distinctives cards. Built via one template generator populated with real historical content (not placeholder text) — Luther's "here I stand" properly hedged as "per later tradition" since it's a disputed-as-apocryphal attribution, his actual documented "epistle of straw" line on James quoted accurately elsewhere. All 11 pages tag-balance clean (including the matrix table), full site-wide smoke test passes. Doctrine's old "Denominational Overviews — Coming soon" stub replaced with a live link to this richer version, as planned.

**THE ENTIRE HISTORICAL DEVELOPMENT EXPANSION IS COMPLETE.** Topics moved+renamed, new Prophecy module, Bible canonization pages, and all 11 denomination pages — 17 new/moved pages this phase, zero broken links anywhere, full site smoke test clean throughout.

## Explicitly NOT in scope for this rebrand
- `tools/commute-companion.html` — stays on its current dark offline-safe styling,
  no Tailwind/CDN/hotlinked photos. It's the one page that still has to work fully
  offline in the truck.
