# LIVING WATERS — START HERE

This zip is the complete, current state of the Living Waters Bible & theology study app.

---

## If you are opening this to READ THE APP

Open **`index.html`** in a browser.

Most of the site needs an internet connection (CDN styles, hotlinked images).
The one exception is **Commute Companion**, which is deliberately 100% offline
and self-contained for tablet use.

To run it as a local server instead (better for some features):
```
python3 server.py
```

---

## If you are opening this to CONTINUE BUILDING

Read this file first:

### → `workspace-build-docs/MASTER-TODO.md`

That is the single source of truth for what's done, what's left, and the exact
plan to finish it. It contains:

- Phase 1 — all remaining scripture text, split into 13 numbered batches
- Phase 2 — translations, lexicon, cross-references, atlas, period pages
- Phase 3 — the 8 confirmed reader/ministry tools
- Phase 4 — known open defects and loose ends
- The standing rules that must not be broken

---

## Current status at a glance

| | Chapters | Verses |
|---|---|---|
| **Genesis — COMPLETE** | 50 | 1,533 |
| Remaining (65 books) | 1,139 | 29,569 |
| Total (KJV) | 1,189 | 31,102 |

Genesis is fully built at panorama standard: every chapter, every verse, KJV
throughout, period-tagged, with shape-view, mini-TOC and scroll-spy navigation.

Beyond scripture text, these are already built out with real content:
Doctrine & Denominations · Bible History (OT/NT canonization) · the full
Topical Studies suite (Millennial Kingdom, Messianic Prophecy, Parables,
Prophecy) · 16 OT prophet books in the older format · Matthew ch 1–3 at full
commentary standard · Commute Companion · Sermon/Plan/Curriculum Builders ·
Journal & Thought Organizer.

---

## The next action

Start a fresh chat, upload this zip plus `MASTER-TODO.md`, and say:

> **Run Batch 0.**

Batch 0 builds the page-generator tooling. It makes every batch after it roughly
three times faster, so it comes before any more books.

---

## Key folders

| Path | What's in it |
|---|---|
| `index.html` | Site entry point |
| `data/panorama-data.js` | **The scripture text itself** — all chapter/verse records |
| `lib/panorama-render.js` | Renders verses + applies word-coloring automatically |
| `lib/living-waters.css` | Site-wide visual identity |
| `scripture-studies/` | All Bible book pages (OT + NT) + period-intro pages |
| `doctrine/` | Doctrine & Denominations |
| `commentary/` | Commentary & Tools layer |
| `apocrypha/` | The Apocrypha |
| `journal/` | Study Journal |
| `tools/` | Sermon Builder, Plan Builder, Commute Companion, etc. |
| `workspace-build-docs/` | **All planning docs — start with MASTER-TODO.md** |
