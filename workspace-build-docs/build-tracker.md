# Scripture Workspace — Build Tracker

## 📍 LIVING WATERS v1.0 — this build

Called as v1.0 by the user at the end of a prior session; updated since as the rebrand rollout
progressed. What v1.0 actually contains as of this update:
- Site/Commute-Companion merge complete (server.py v2, unified plan system, journal w/ archive)
- Small Group Curriculum Builder + Reading Plan Builder tools, wired together
- LIVING WATERS rebrand: homepage flagship (live ticker, dawn-horizon device, rotating photo
  backdrop w/ 6 reserved local-photo slots, real cross-reference carousel) — **plus ALL 6 section
  indexes, all 21 book-level pages, all 3 topical modules, Doctrine's Church History page, all
  6 deep-dive commentary pages, AND all 55 individual chapter/room pages converted.
  102 pages total — the entire visual rollout is complete.** On top of that, the full
  **Historical Development expansion is also complete**: `topics/` moved+renamed to
  `scripture-studies/topical-studies/`, a new Prophecy topical module, OT/NT canonization pages,
  and all 10 denomination deep-dive pages with their comparative matrix hub. Nothing site-wide
  is left on the old look except Thought Organizer and Apocrypha's coming-soon template. See
  `lib/LIVING-WATERS-CHECKLIST.md` for the full detail
- Matthew 1 brought to the new verse-by-verse, differences-only, Scripture-explains-Scripture,
  verified-commentator, Early-Church-context commentary standard — see
  `bible-commentary-master-tracker.md` for the full methodology and what's still queued (8 more
  existing Matthew chapters need the same revision, 19 need building from scratch, then
  Mark/Luke/John/Acts/Romans haven't started)

**Not done, still knowingly:** the individual chapter/room pages site-wide are still on the old
illuminated or dark-slate look — only the navigation layer plus the 3 topical modules are fully
Living Waters so far. This is a real, named checkpoint, updated in place — not a claim that the
rebrand or the commentary project are finished.

---
**Last synced from:** study-hub-v25.zip
**Last updated:** 2026-08-02

> HOW TO USE THIS FILE: Re-upload this tracker (alongside the current site zip) at the start of any session and say
> "Continue the build — pick up from here." I'll read the queue below and keep going. Update the tables yourself
> whenever you make manual edits outside our chats, so the record stays accurate.

---

## 1. Site Inventory (as of v25)

### Topics module
| Topic | Status |
|---|---|
| Messianic Prophecy (birth, ministry, passion, death/burial/resurrection, reign) | ✅ Built |
| Millennial Kingdom (Rev. 20, NT witnesses, historical development) | ✅ Built |
| Parables of Jesus | 🟡 In progress — see §3 |

### Scripture Studies — New Testament
| Book | Chapters built | Status |
|---|---|---|
| Matthew | 1, 2, 3, 5, 6, 16, 26, 27, 28 | 🟡 Partial |
| John | 1, 6 | 🟡 Partial |
| Jude | 1 (full book) | ✅ Complete |
| Philemon | 1 (full book) | ✅ Complete |
| Revelation | index only, no rooms yet | 🔴 Not started |
| All other NT books | — | 🔴 Not started (coming-soon page live) |

### Scripture Studies — Old Testament
| Book | Chapters built | Status |
|---|---|---|
| Genesis | 1, 3, 6, 12, 18, 22, 37 | 🟡 Partial |
| Isaiah | 2, 9, 11, 24, 60, 65 | 🟡 Partial |
| Jeremiah | 23, 30, 31, 32, 33 | 🟡 Partial |
| Ezekiel | 34, 36, 37, 40, 47, 48 | 🟡 Partial |
| Daniel | 2, 7, 9, 12 | 🟡 Partial |
| Zechariah | 9, 12, 14 | 🟡 Partial |
| Hosea | 3 | 🟡 Partial |
| Joel | 2, 3 | 🟡 Partial |
| Amos | 9 | 🟡 Partial |
| Obadiah | 1 (full book) | ✅ Complete |
| Micah | 4, 5 | 🟡 Partial |
| Nahum | index only | 🔴 Not started |
| Habakkuk | 2 | 🟡 Partial |
| Zephaniah | 3 | 🟡 Partial |
| Haggai | 2 | 🟡 Partial |
| Malachi | 4 | 🟡 Partial |
| Jonah | index only | 🔴 Not started |
| Exodus, Proverbs, Psalms | — | 🔴 Not started (in Prompt 2 priority list) |

### Commentary suite (deep-dive)
| Book | Status |
|---|---|
| Genesis, Matthew, John, Acts, Romans, Revelation | ✅ Deep-dive page exists |
| Format/depth vs. new blueprint (Prompt 2) | 🟡 Needs review against new 4-part template |

### Doctrine, Apocrypha, Tools
| Module | Status |
|---|---|
| Doctrine — Church History | ✅ Built |
| Apocrypha | 🔴 Coming-soon placeholder only |
| Tools — Sermon Builder, Thought Organizer | ✅ Built |

---

## 2. Prompt Queue (your 11-prompt execution plan)

| # | Prompt | Status |
|---|---|---|
| 1 | Parables of Jesus — 3-tier catalog | ✅ Delivered (8 parables: Sower, Wheat & Tares, Mustard Seed/Leaven, Lost Sheep/Coin/Prodigal Son, Good Samaritan, Laborers in Vineyard, Talents/Minas, Ten Virgins) — **not yet inserted into site HTML rooms** |
| 2 | NT & Priority OT Commentary Suite & Historical Arcs | 🟡 Blueprint + template delivered; Genesis 1 worked as proof-of-concept. Full book-by-book exegesis not yet built. |
| 3 | AI Sermon Builder & Small Group Curriculum Suite | 🟡 Architecture + workflows delivered for both engines. One worked sermon (Luke 15:11–32) and one worked small-group session (Matt. 13:1–23, Week 1 of 4) delivered as samples. **Note:** existing `tools/sermon-builder.html` is currently just a prompt-assembler, not a generator — actual HTML/JS build for real generation engine not yet written for either tool. |
| 4 | Visual UI/UX Overhaul & Card Architecture | 🟡 Design tokens, Tiered Study Card, Timeline Parallel Card, Symbol Lookup Card, 12-period color scheme, and Driver Mode/START COMMUTE spec all delivered with CSS samples. **Open decision pending from you:** whether to migrate `tools/*.html` (currently a separate dark-slate palette) onto the v19 system as part of this pass. Actual implementation into live site files not yet done. |
| 5 | Interactive Kings & Prophets Timeline Engine | ✅ Full data schema + complete Israel/Judah regnal matrix (931–586 BC, all 19 Israel + 20 Judah kings) + prophet-mapping table + 2 worked Timeline Parallel Cards delivered. **Found a UI gap:** Prompt 4's card spec needs a single-kingdom mode for post-722 BC (after Israel falls) — feed this back into Prompt 4 before implementation. |
| 6 | Temples & Sacred Architecture Module | ✅ Comparison matrix (Tabernacle, Solomon's, Zerubbabel's, Herod's, Ezekiel's visionary), structural breakdowns, furnishings catalog, full typology/fulfillment matrix, priestly duties summary delivered. **Note:** Ezekiel's temple presented with 3 interpretive options (literal millennial / symbolic / typological-in-Christ) left neutral, matching site's existing Millennial Kingdom approach. **Build note:** should link to existing Ezekiel ch.40/47/48 rooms rather than duplicate. |
| 7 | Live-First Network Architecture Boundary | 🟡 **REVISED.** Storage tiering, IndexedDB schema, sync protocol still valid. AI-generation model corrected: not live conversation, but a pre-generated teaching monologue (see Prompt 8 revision). Backend hosting decision still open. |
| 8 | Pre-Cached Commute Engine & Driver Mode | 🟡 **REVISED FOUR TIMES.** Final model: **two dead zones** — Zone 1 at trip start (~5–10 min, default-to-cached rather than predict), Zone 2 on US-74 through Andrews, NC (4-lane→2-lane) to near the Nantahala Outdoor Center (~**30 min**, corrected via distance/speed math from user's 40–45 mph estimate — road distance ~20–22 mi against ~15.9 mi straight-line between confirmed coordinates: Andrews ~35.2018,-83.8241 → NOC ~35.3313,-83.5917). Total fallback content needed: ~35–40 min/day. Hybrid model unchanged otherwise: live AI conversation when signal's up, GPS-anticipated handoff into/out of Zone 2, pre-generated monologue + voice notes as the offline content. See `prompt7-8-revision-reading-plan.md` §7 for full writeup incl. coordinates and math. |
| 8b | Bible in a Year reading plan integration | ✅ PDF parsed — **365/365 days extracted cleanly, zero errors.** Delivered as `bible-in-a-year-plan.json`. Day 214 cross-checked against user's stated position — confirmed exact match (plan tracks straight calendar day-of-year, no offset). This becomes the "today's reading" auto-source for the Commute Engine. |
| 9 | Revelation & Apocalyptic Literature Engine | ✅ OT Allusion & Source Matrix (12 major image-to-source mappings), Heavenly Temple liturgical mapping (extends Prompt 6 directly), and full 7-part profiles for all Seven Churches delivered. **Note:** kept neutral on contested interpretive questions (preterist/historicist/futurist/idealist views, millennium), consistent with the Millennial Kingdom module's existing approach. **Build note:** recommend linking to existing Temples module rather than duplicating; Seven Churches section maps cleanly onto the Tiered Study Card component from Prompt 4. |
| 10 | Biblical Symbolism & Numerology Engine | ✅ 10-symbol dictionary (Water, Fire, Horns, Wilderness, Oil, Rock, Shepherd, Bridegroom, Babylon, Jerusalem) with full Genesis-to-Revelation arcs; numerology table (3, 7, 10, 12, 40, 70, 144,000) with explicit sound-typology-vs-speculation boundary rule; Symbol Lookup Card template + worked example ("Shepherd") delivered. **Note:** flagged Daniel's "70 weeks" as genuinely contested rather than settled, and 144,000 explicitly addressed as symbolic-structure (12×12×1,000) rather than literal headcount, to head off common speculative misreadings. |
| 11 | Deep-Dive Topical Suite | 🟡 Systematic module template + full cross-reference matrices + 2 fully worked modules (Election/Predestination, Sacraments/Ordinances) delivered, each with 4 denominational positions presented fairly, historical development, and export-ready summaries for Sermon Builder/Commute Engine. **Note:** kept strictly neutral across traditions (Reformed/Arminian/Catholic-Orthodox/Molinist for election; Catholic-Orthodox/Lutheran/Reformed/Baptist for sacraments) — presented each view's strongest support and the strongest objection against it, no verdict given. Remaining topics (Spiritual Warfare, Covenant Theology, Eschatology, Ethics) have the template ready but aren't built out yet — Eschatology should link to existing Millennial Kingdom module rather than duplicate. |
| 12 | Dynamic Source & Perspective Expansion Engine | ✅ Lens switcher config schema, 5 preset tradition filters, custom blend selector, PDF Vault + Web Crawler RAG pipeline architecture, grounding/priority rules, and Comparative Commentary Mode (extends Tiered Study Card) all delivered. **⚠️ Flagged naming ambiguity:** "Armstrong" in the prompt's example voice list is unclear — could refer to a commentator well outside historic Christian orthodoxy; needs clarification before building the actual preset list. **⚠️ Copyright boundary built into the spec:** public-domain sources (Calvin, Luther, Henry, Spurgeon) can be fully ingested; modern copyrighted commentary sites should be excerpt/paraphrase + link-out only, not full-text mirrored. This is the most backend-dependent module yet — squarely blocked on the same open Prompt 7 hosting decision, now carrying more weight (vector DB + embeddings + crawler service). |

**🏁 All 12 prompts in the queue now have a delivered architecture/content pass.** See the "Master System Status" summary in `prompt12-source-perspective-engine.md` §5 — the honest state is: every module is genuinely specced with real sample content and real data, but almost none of it is built into the live site yet. The three standing decisions below are the actual bottleneck, not further specification.

---

## ⚠️ Correction Needed: Prompt 4's Period Color Scheme

Prompt 4's 12-period color table was **invented without checking against the user's actual Bible in a Year plan**, which uses Jeff Cavins' Great Adventure Bible Timeline — a specific named 12-period framework. The two don't match (wrong names, wrong boundaries, an invented "Assyrian Crisis" period that doesn't exist in the real scheme, and Messianic Fulfillment/The Church wrongly merged into one).

**Real scheme (extracted directly from the user's plan):** Early World → Patriarchs → Egypt and Exodus → Desert Wanderings → Conquest and Judges → Royal Kingdom → Divided Kingdom → Exile → Return → Maccabean Revolt → Messianic Fulfillment → The Church, plus a recurring "Messianic Checkpoint" Gospel interlude (not a 13th period) at days 99, 154, 258.

**Action needed:** replace Prompt 4 §3's color table with this real scheme before any more content gets tagged against the wrong one. Small fix now, bigger pain later if left.

---

## 3. Immediate Next Steps (pick up point)

**⚠️ Top priority — blocks further build progress on network-dependent features:**
0a. **Backend/infrastructure decision:** how does the teaching-monologue generation actually get served while online? (real API+DB vs. serverless/BaaS). Accounts/cross-device sync: in scope or not?
0b. **Native app vs. website decision:** the commute piece (voice capture, background audio, offline reliability) needs a native app; Bible study/reading can stay a website. Confirm this split is acceptable, or if full native is preferred for everything.
0c. **Fix Prompt 4's period color table** to match the real Jeff Cavins 12-period scheme (see correction box above) — small task, do it before more content gets tagged.

1. **Parables module:** decide whether Sower/Good Samaritan/Prodigal Son (already live in v25) should be replaced/upgraded with the new 3-tier format, and whether to add the other 5 parables from the catalog as new room pages.
2. **Commentary suite:** choose the next book/chapter range to fully exeget in the new 4-part template (e.g. "Genesis 1–11," "John 1," or align with an existing deep-dive page like `commentary/genesis-deep-dive.html`).
3. **Sermon Builder / Small Group tools:** decide if I should now write the actual `tools/sermon-builder.html` generation engine (replacing the current prompt-assembler) and a new `tools/small-group-builder.html`, using the architecture + samples in Prompt 3's output.
4. **Design system decision:** confirm whether to migrate `tools/*.html` onto the v19 palette now, or leave as-is and only apply the new design system to new components going forward.
5. **Timeline Parallel Card fix:** add single-kingdom mode to Prompt 4's card spec before implementing (needed for post-722 BC, Hezekiah onward).
6. **Temples module:** link new module to existing Ezekiel ch.40/47/48 rooms rather than duplicating content when implementing.
7. **Decide full-Bible offline bundling** — bundle entire Bible text at install vs. cache-as-visited (leaning toward full bundle given the outage pattern).
8. **Revelation module:** link temple-mapping section to existing Temples module (Prompt 6) rather than duplicating; consider building the Seven Churches section as Tiered Study Cards.
9. **Symbolism module:** build out the "See also" cross-links first (Temples, Kings & Prophets, Revelation) — this is what makes it a useful lookup tool rather than a standalone read.
10. **Topical Suite:** decide which of the remaining topics (Spiritual Warfare, Covenant Theology, Eschatology, Ethics) to build out next; Eschatology should link to the existing Millennial Kingdom module rather than duplicate.
11. **⭐ Illuminated redesign — priority.** User loved a hand-built "illuminated manuscript" visual direction (dark-to-light gradient, rounded Blue Ridge mountain horizon, drop caps, rubricated verse numbers, Fraunces/Source Serif 4/Space Grotesk type). This also directly fixes 2 of 3 items from the site audit (font size, and — once pages are chunked into the tier pattern — wordiness). Shared framework built: `lib/illuminated.css` + `lib/illuminated.js`. Converted so far: homepage, `scripture-studies/index.html`, Genesis 1 room, Isaiah 9 room, **and now `commentary/revelation-deep-dive.html`** (see item 12). 106 pages still on the old dark-slate design — full numbered checklist + ready-to-paste conversion prompts in `lib/CONVERSION-CHECKLIST.md`.
12. **⭐⭐ Bible Commentary Project — NEW, top priority, formally tracked.** User wants full chapter-by-chapter commentary on every NT book (near-term) and eventually the whole Bible. **Revelation is done** — all 22 chapters, real depth (movement/key words/typology/teaching notes), delivered as `revelation-full-commentary.md` AND redesigned into the illuminated site page. Full master tracker with all 27 NT books + phased OT plan now lives in `workspace-build-docs/bible-commentary-master-tracker.md` — same reusable-prompt pattern as the site conversion checklist, so this never stalls again. **Open question for user:** confirm format going forward — standalone content file, illuminated site page, or both (both is what happened with Revelation).
13. **Clarify "Armstrong":** which commentator was meant in Prompt 12's base-layer voice list — needs resolving before that preset list gets built for real.
14. **The three standing decisions (repeated because they now block everything):**
    - Backend hosting approach — now serving the commute engine's generation step AND the RAG pipeline
    - Native app vs. website scope for the commute piece
    - Prompt 4's period color table correction (small, still unblocked, still not done)
15. **Next session:** two active tracked initiatives now running in parallel — the illuminated redesign (`lib/CONVERSION-CHECKLIST.md`) and the Bible Commentary Project (`workspace-build-docs/bible-commentary-master-tracker.md`). Bring either's prompt template, or a fresh Prompt from the original 12-prompt queue if picking that back up.

---

## 4. Session Log
| Date | What happened |
|---|---|
| 2026-08-02 | Reviewed v25 zip inventory. Delivered all 12 prompts as files this session (see table above) — Parables catalog, Commentary blueprint, Sermon/Small Group architecture, UI design system, Kings & Prophets timeline, Temples module, Network architecture (later revised), Commute Engine (revised twice more for real commute constraints), Revelation & Apocalyptic module, Symbolism/Numerology engine, Topical Suite (2 of 6 topics fully worked), and the Source/Perspective Expansion Engine. Confirmed existing `sermon-builder.html` is a prompt-assembler, not a generator. Flagged palette conflict between v19 and tools/*.html. Flagged single-kingdom card UI gap. Flagged content-duplication risk with existing Ezekiel rooms. Major real-world discussion after Prompt 8: user's actual commute has two dead zones (start-of-trip ~5-10 min, and a math-confirmed ~30 min stretch through Andrews, NC to the Nantahala Outdoor Center) — redesigned as hybrid live/pre-cached model with GPS-anticipated switching. User uploaded their actual Bible in a Year (Fr. Mike Schmitz) reading plan PDF — parsed all 365 days cleanly into `bible-in-a-year-plan.json`, confirmed Day 214 matches user's stated position exactly. Discovered and flagged that Prompt 4's period color scheme didn't match the real Jeff Cavins 12-period framework. Did a real code-level site audit (word counts, actual font sizes, actual palette usage across all 111 files) — found the site averages 3,500+ words/page, found passage text renders smaller than base size, corrected an earlier claim about the palette split. Built 2 layout experiments; user picked the illuminated-manuscript direction, pushed it toward award-caliber design with a dawn-over-mountains structural device (corrected from sharp Alpine peaks to rounded Blue Ridge ridgelines per feedback). User approved and asked for the whole site — built the real shared `lib/illuminated.css`/`.js` framework, converted one example of each major page type rather than risk a blind bulk conversion, delivered a full 107-page numbered checklist with ready-to-paste batch prompts. **User then asked for full Revelation commentary (expand + redesign) and, more importantly, named the recurring pattern of this getting deferred and asked for a real systematic plan for the whole Bible.** Delivered: full 22-chapter Revelation commentary (real depth, cross-linked to Prompts 6/9/10 and the Millennial Kingdom module), redesigned as an illuminated site page with working chapter jump-navigation, AND a new formally-tracked Bible Commentary Project master tracker (all 27 NT books phased, OT queued, same reusable-prompt system as the site checklist) so this stops stalling. Tracker updated as a standing habit after each completed step. |

---

## 5. Site/Commute-Companion Merge — 4 of 5 steps done, one blocked on you

### What user asked for (all in one pass):
1. Merge `commute-companion-app` (the phone AI-chat tool) into the main Study Hub site — one server, not two separate things
2. A real "Save to My Study" button — currently discussions only go to clipboard, nothing is saved anywhere
3. An archive system so the saved-journal index doesn't grow unbounded (archive, not delete — nothing destroyed, just kept off the main index)
4. A generalized multi-plan system — the app was hardcoded to just Bible-in-a-Year; needs to also support a real 4-day/week group Bible study, plus future custom-generated studies

### What's done this session:
- ✅ `data/plans/bible-in-a-year.json` — generic schema `{plan_id, name, cadence, start_date, meeting_days, sessions:[{session, title, readings, notes}]}`. 365 sessions, verified (session 215 = Isaiah 51-52, Ezekiel 12-13, Proverbs 12:21-24).
- ✅ `server.py` v2 — serves the whole site's static files (not just one page) via a guarded catch-all route; `/api/chat` unchanged; new `/api/plans` (lists plans + computed current session — daily cadence = day-count since start_date, non-daily cadence = real meeting-day occurrences since start_date, not calendar days); `/api/plans/<id>` (full plan detail); `/api/journal/save`; `/api/journal/archive`. Smoke-tested via Flask test client — all routes return correct data, current session computed correctly for the live Bible-in-a-Year plan.
- ✅ `tools/commute-companion.html` — moved into the site from the standalone app, hardcoded PLAN array replaced with live `/api/plans` + `/api/plans/<id>` fetches, plan switcher dropdown added, "Today" button added, real "Save to My Study" button wired to `/api/journal/save` (Copy button kept alongside it, not replaced).
- ✅ Journal system — `data/journal/entries.json` is the source of truth (id, plan_id, session, refs, date_saved, summary, commentary, archived). `server.py`'s `render_journal_pages()` regenerates `journal/index.html` (live entries, illuminated style, ilm-card grid) and `journal/archive.html` (archived entries grouped by year) on every save/archive and once on boot. Archiving moves an entry off the live index into the archive page — never deletes it.
- ✅ Homepage (`index.html`) and `commentary/index.html`'s Tools section both got "Commute Companion" and "My Study Journal" cards/links — no longer hidden URLs.

### Step 4 — open, not urgent:
No 4x/week group study is currently running. Confirmed active studies right now are individual Revelation study and Bible in a Year (currently day 215 — matches the server's computed current_session exactly). The generalized plan system is proven with one real plan; a second plan (group study or otherwise) gets added whenever one actually exists, using the same schema. Don't prompt for this again until the user brings a real plan to build.

---

## 6. Small Group Curriculum Builder — built into Scripture Workspace & Sermon Builder

User doesn't want plans authored by hand in chat — wants a real Reading Plan Builder tool (not yet built) that they use themselves, plus the ability to convert Curriculum Builder output into a plan, plus file-upload import. Sequencing: build the Curriculum Builder first (done this session), Reading Plan Builder next, then wire the two together.

**Built this session:** `tools/sermon-builder.html` — Prompt 3's blueprint (`workspace-build-docs/prompt3-sermon-smallgroup-suite.md`) implemented as a new "4 · Small Group Curriculum Builder" section on the same page (user's call — "into the sermon builder area", not a separate file). Inputs: topic/passage, number of weeks (1-20), group type, commitment level (light/standard/deep-dive, changes discussion-question depth per the blueprint's constraint-handling rule), optional shaping notes. Unlike the existing Sermon section (still a prompt-assembler by design), this is a REAL generator — it calls `/api/chat` directly (same endpoint Commute Companion uses) with a system prompt built from the exact per-session template (Leader Guide / Icebreaker / Discussion Questions / Participant Handout) and writes all N weeks in one pass. Optional plain-text/audio-friendly variant generation included per the blueprint's Commute Engine integration note (section 3) — a second `/api/chat` call rewrites the output with explicit spoken section markers and no tables/nested bullets, for future TTS use. Output has copy-to-clipboard and download (.md for the main version, .txt for the audio variant).

**Not done / next:**
- The actual Sermon Builder generation engine (section 1 of the blueprint) — still a prompt-assembler, not real generation; not requested to change yet.

---

## 7. Reading Plan Builder — built, and wired to the Curriculum Builder

`tools/plan-builder.html` — a real, self-serve tool. No fixed duration or cadence assumed (per explicit user correction: not locked to "4 weeks" — a plan can be 3 days, 4 weeks, 6 months, a full year, anything). Three ways in:
1. **Manual entry** — plan name/description/plan_id (auto-slugged), start date, cadence (Daily, or specific weekdays for any Nx/week schedule), and a session list (add one at a time or several blank at once, each with title/readings/notes, freely editable/removable).
2. **Load an existing plan to edit** — dropdown pulls from `/api/plans`, loads via `/api/plans/<id>`, fills the form for editing and re-saving (same endpoint handles create and update).
3. **AI-assisted file import** — upload a .txt/.csv/.md reading plan, sent to `/api/chat` with a strict "return only a JSON array of sessions" system prompt, parsed and appended to the current session list (doesn't overwrite what's already in the form). Needs internet for this step.

**Server side:** new `/api/plans/save` (POST) in `server.py` — validates name/sessions/start_date/meeting_days, slugifies `plan_id`, writes `data/plans/<plan_id>.json`, returns the saved plan with computed `current_session`. Smoke-tested (custom Mon/Wed cadence plan created, listed, and fetched correctly).

**Wired to the Curriculum Builder (the sequencing the user asked for):** the Curriculum Builder's "Send to Reading Plan Builder →" button stores the generated curriculum text + topic/weeks in `localStorage` and navigates to `plan-builder.html`, which detects it on load, offers "Turn this into a plan," and runs it through the same AI-parse-into-sessions pipeline as file import. User still picks the real meeting day(s) and start date before saving — nothing is assumed.

**Also added:** a "Manage / add plans →" link from Commute Companion's plan switcher straight to the builder, and Reading Plan Builder cards/links on `commentary/index.html`'s Tools section.

**Not done / next:** nothing outstanding from the user's ask — this closes out the three-part sequencing (Curriculum Builder → Plan Builder → wire together). Open item is only the same one as section 5: no second real plan exists yet to build with this tool.

---

## 8. LIVING WATERS rebrand — homepage flagship built, rest of site pending

User uploaded a prototype (`living_waters_engine.html` — Tailwind/glassmorphism, teal/emerald/amber, misty mountain backdrop, top+bottom tickers, rotating spotlight, voice AI button) and wants the whole site rebranded to this look. Confirmed explicitly: **offline-only requirement is scoped to Commute Companion now** — the rest of the site can be online, so CDN dependencies (Tailwind, FontAwesome, Google Fonts) and hotlinked photos are fine everywhere except the Commute Companion page itself, which should stay offline-safe.

**Built this session:**
- `lib/living-waters.css` / `lib/living-waters.js` — shared design system (glass panels, ticker/marquee animation, aura pulse, rotating photo backdrop with graceful `onerror` fallback if a hotlink is offline/dead, generic rotating-carousel helper, live-plan-fetching ticker builder, read-aloud helper). Built as shared files (like `lib/illuminated.css/js`) so the rest of the site can reuse them as pages get converted.
- `index.html` rebuilt as the flagship Living Waters page — real content throughout, not the prototype's placeholder text: top ticker and the "Today's Focus" card both pull the live current plan reading from `/api/plans`; the rotating "spotlight" card carries four real, uncontroversial living-water cross-references (Genesis 2:10, Zechariah 13:1, John 7:37-39, Ezekiel 47/Rev 22) tied to modules already in the app; bottom research ticker carries real Hebrew-lexicon/canonical-harmony content instead of placeholder "Research Note 104" text; "Talk to AI" routes straight into the real Commute Companion instead of a fake voice modal; full section-card navigation to every real part of the site preserved. Old illuminated homepage backed up at `/home/claude/work/index-OLD-illuminated-backup.html` (not shipped in the zip).
- Rotating background photos of the actual area — confirmed U.S. Forest Service (public domain) photos of Fires Creek/Nantahala National Forest (Clay County, borders Murphy) and Brasstown Bald (~25 min from Murphy), plus two Creative-Commons-licensed ones (Whitewater Falls, and a Lake Chatuge sunset near Hiawassee) added at the user's request for more variety — each image keeps its real, honest credit/license in `lib/living-waters.js`'s `LW_PD_IMAGES`/`LW_CC_IMAGES` arrays rather than being mislabeled as public domain across the board.
- Small supporting add: `tools/sermon-builder.html` now accepts `?ref=` in the URL to prefill the passage field, so the homepage's "Search in Workspace" link actually lands on the right passage.

**Not done / next — this is a real scope call, not an oversight:**
- Only the homepage is converted. Propagating the Living Waters look to the rest of the site (Scripture Studies, Doctrine, Apocrypha, Topics, Commentary, Tools, Journal — the same ~100+ pages the old Illuminated Redesign checklist tracked) has NOT started. Converting everything in one pass wasn't realistic to do well; this needs its own tracked checklist the way `lib/CONVERSION-CHECKLIST.md` tracked the Illuminated rollout. Recommend: build that checklist next, reusing the same page-by-page structure, before converting pages.
- Commute Companion (`tools/commute-companion.html`) should almost certainly NOT get the Tailwind/CDN/hotlinked-photo treatment even after the rest of the site converts, since it's the one page that still needs to work fully offline in the truck.
- Image variety is still thin (4 sourced images). Local phone photos from the user would be the most authentic option and sidestep the PD-vs-CC-attribution question entirely — **now built:** 6 reserved local-photo slots (`data/photos/local-01.jpg` through `local-06.jpg`, see `data/photos/README.md` for exact filenames/subjects) in the backdrop rotation. Until a real file exists at a given path, that slot shows a labeled on-brand placeholder ("Your photo here — [suggested subject]") instead of a broken image or just vanishing, so the rotation always looks intentional. User said they have specific photos and will supply the actual files next.
- Added the dawn-horizon device back in (user liked this from the old illuminated homepage — dark sky breaking into light right at the mountain ridgeline) — rebuilt in the Living Waters teal/amber palette rather than copied verbatim: three layered ridge silhouettes (same path shapes, recolored), a radial amber/teal glow pulsing behind the ridgeline, and a slow-rotating conic-gradient light-ray sunburst behind that. Sits between the header and the main hero.

**Rollout begun:** `lib/LIVING-WATERS-CHECKLIST.md` created, mirroring the old Illuminated checklist's structure/approach. Section indexes converted this session: `topics/index.html` (4 cards), `doctrine/index.html` (6 cards), `apocrypha/index.html` (9 book cards + history-note + framing-note callouts, all real content/links preserved verbatim), `commentary/index.html` (6 book cards + full Tools list — this one had no reader-tools apparatus to protect, so it got a full rewrite rather than a surgical swap). Confirmed pattern: swap only the header/grid HTML block + add CDN deps to `<head>`, leave each page's inline reader-tools apparatus (highlight/note/verse-modal — duplicated per page) completely untouched. All four smoke-tested (tag balance, reader-tools JS/includes intact where present, serve correctly through `server.py`). Only the two big scripture-studies indexes (~39 and ~27 book entries) remain in section A — queued next, deliberately not rushed into this same pass given their size.

### Already working, NOT part of this merge (don't redo):
- `commute-companion-app.zip` (the standalone version) — phone/Termux deployment, `start-commute.sh` one-tap widget script. Still works today, independently. The merge folds a copy into the main site; it doesn't replace or break the standalone one.

### Reusable prompt to resume next session (once you've given the group study topic):
```
Continue the site/commute-companion merge — step 4 only. Build [TOPIC/BOOK]
as a second plan in data/plans/, starting [DATE], meeting [DAYS], in the
same generalized schema as bible-in-a-year.json.
```
