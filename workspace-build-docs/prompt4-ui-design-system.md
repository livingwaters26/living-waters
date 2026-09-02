# Visual UI/UX Overhaul — Design System & Component Blueprints

**Flag before starting:** the site currently has two competing visual languages —
1. `lib/hub-ui.css` ("v19") — a warm, premium academic palette: paper/vellum, indigo, brass, oxblood, serif headers. This is used across scripture-studies, topics, doctrine.
2. `tools/sermon-builder.html` and `tools/thought-organizer.html` — a dark slate/gold tech palette (`#0f172a` bg, amber/blue accents), unrelated to v19.

This blueprint extends **v19** as the single system of record (it's the more developed, intentional design), and folds the tools pages into it rather than inventing a third palette. Worth confirming that's the direction you want before I touch the tools pages.

---

## 1. Design System Tokens (extends v19)

```css
:root{
  /* existing v19 base — unchanged */
  --v19-ink:#1B2027; --v19-ink-soft:#4A5361; --v19-paper:#FBFAF7;
  --v19-vellum:#F3EFE6; --v19-rule:#D9D2C4; --v19-indigo:#2F3E68;
  --v19-brass:#A8842C; --v19-brass-lt:#E8D9A8; --v19-sage:#4A6B4F;
  --v19-amber:#B8862B; --v19-oxblood:#7B2E2E;

  /* new: card system spacing/radius scale */
  --card-radius: 14px;
  --card-pad: 20px;
  --card-gap: 16px;
  --tier-indent: 14px;

  /* new: interactive state layer */
  --state-hover: rgba(168,132,44,0.08);   /* brass tint */
  --state-active: rgba(168,132,44,0.16);
  --state-focus-ring: var(--v19-brass);
}
```

**Typography:** headers stay on `--v19-serif` (Iowan Old Style/Palatino/Georgia) for theological-academic weight; card body and UI chrome (buttons, labels, metadata) use `--v19-sans`. No new typefaces introduced — consistency with existing reading-comfort system (the A-/A+ control) is preserved.

---

## 2. Modular Card Architecture

### 2.1 Tiered Study Card
The base unit for parables, commentary, and topical rooms — matches the 3-tier structure already used in the Parables/Commentary output.

**Structure:**
- **Header Tags** — small caps metadata row: passage reference, tier count, reading-time estimate. Uses `--v19-brass` on `--v19-vellum`.
- **Body States:**
  - *Collapsed:* Tier 1 heading + first line preview only (for scanability on topic index pages).
  - *Expanded:* full tier content, standard paragraph + bullet formatting, `max-width: 68ch` (matches existing `.v19 p` rule).
  - *Sub-sections:* nested bullets indented by `--tier-indent`, never more than 2 levels deep (readability guard).
- **Interactive Triggers:** each tier header is a button (`aria-expanded`, `aria-controls`) toggling a `max-height` transition; all three tiers can be open simultaneously — this isn't an accordion that forces single-open, since cross-tier comparison is common study behavior.

```css
.tiered-card{ background:var(--v19-paper); border:1px solid var(--v19-rule);
  border-radius:var(--card-radius); padding:var(--card-pad); margin-bottom:var(--card-gap); }
.tiered-card .tag-row{ font:600 11px/1 var(--v19-sans); letter-spacing:.05em;
  text-transform:uppercase; color:var(--v19-brass); margin-bottom:10px; }
.tier-trigger{ width:100%; text-align:left; background:none; border:none;
  border-top:1px solid var(--v19-rule); padding:12px 0; font:700 1rem var(--v19-serif);
  color:var(--v19-indigo); cursor:pointer; display:flex; justify-content:space-between; }
.tier-trigger:hover, .tier-trigger:focus-visible{ background:var(--state-hover); }
.tier-body{ max-height:0; overflow:hidden; transition:max-height .25s ease; }
.tier-body.open{ max-height:1000px; padding-bottom:14px; }
```

### 2.2 Timeline Parallel Card
For Kings/Prophets cross-referencing — shows a monarch or era alongside contemporaneous prophetic voices.

**Structure:** two-column layout on desktop (collapses to stacked on mobile <640px): left column = throne/political timeline entry (king, dates, kingdom N/S), right column = prophets active in that window, each tagged with the timeline color of their era (see §3). A connecting rule (`border-left: 3px solid [era-color]`) ties the pair visually.

### 2.3 Symbol Lookup Card
For numerology/symbolism reference — compact, dictionary-style, not tiered.

**Structure:** symbol/number as large serif numeral or icon header → primary meaning (1 sentence) → 2–3 scriptural instances as a tight list → "see also" cross-links. Deliberately terse; this card is for lookup speed, not deep reading, so it breaks from the tiered pattern intentionally.

---

## 3. Historical Timeline — 12-Period Color Scheme

| # | Period | Color | Hex |
|---|---|---|---|
| 1 | Creation & Pre-Patriarchal | Slate blue-grey | `#5B6B8C` |
| 2 | Patriarchs | Blue | `#3B5A8C` |
| 3 | Egypt & Exodus | Terracotta | `#B5562C` |
| 4 | Wilderness & Conquest | Ochre | `#C08A2E` |
| 5 | Judges | Olive | `#6B7A3A` |
| 6 | United Monarchy | Brass (v19 native) | `#A8842C` |
| 7 | Divided Kingdom | Rust | `#8C4A2E` |
| 8 | Assyrian Crisis | Charcoal red | `#7A3B3B` |
| 9 | Babylonian Exile | Purple | `#5B3B6B` |
| 10 | Post-Exilic Return | Teal | `#2E6B6B` |
| 11 | Intertestamental | Grey | `#6B6B6B` |
| 12 | Messianic / Early Church | Gold | `#B8862B` |

Rule: this exact mapping persists everywhere a period is referenced — timeline views, Timeline Parallel Cards, era tags on commentary rooms, and the salvation-history arc pages from Prompt 2. Store as a single JS/CSS lookup (`data/timeline-colors.js`) rather than hardcoding hex values per page, so it only needs to change in one place.

---

## 4. Driver Mode / Commute Engine Interface

### 4.1 "START COMMUTE" Hero Button
```css
.commute-hero-btn{
  width:100%; height:120px; border-radius:20px; border:none;
  background:linear-gradient(135deg, var(--v19-indigo), var(--v19-oxblood));
  color:var(--v19-brass-lt); font:700 1.5rem var(--v19-serif); letter-spacing:.03em;
  display:flex; align-items:center; justify-content:center; gap:14px;
  box-shadow:0 6px 20px rgba(0,0,0,0.25);
}
.commute-hero-btn:active{ transform:scale(0.98); }
```
120px height satisfies large-touch-target accessibility guidance well beyond WCAG's 44px minimum — appropriate given this is meant to be tappable without looking, i.e. genuinely eyes-free.

### 4.2 Driver Mode-Safe UI Rules
- **Max 3 controls visible at once:** play/pause, skip, voice-capture. Everything else (speed, chapter select) lives one tap deeper, never on the primary screen.
- **Voice capture icon:** minimum 96px diameter, fixed bottom-center, high-contrast fill (no outline-only icons — must read instantly in peripheral vision).
- **No body text smaller than 28px** anywhere in Driver Mode — this screen is glanced at, not read.
- **No color-only state indication:** playing/paused must differ in icon shape, not just color, for glare/glance conditions.

---

## 5. Open Decision for You

Before I build any of this into actual site files: confirm whether to (a) migrate `tools/*.html` onto the v19 palette as part of this pass, or (b) leave tools alone for now and only apply this system to new components (cards, timeline, Commute Engine). Affects how much file-touching Prompt 4's actual implementation involves.
