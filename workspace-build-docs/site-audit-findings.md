# Site Audit — Scripture Workspace v25/v100

I went into the actual files this time — word counts, font sizes, which stylesheets each page really loads — rather than describing things in the abstract. Findings below are measured, not impressions.

---

## 1. Wordiness — confirmed, and worse than "a bit much"

| Page | Word count |
|---|---|
| `doctrine/church-history.html` | **6,577 words** on one page |
| `topics/messianic-prophecy/rooms/birth.html` | 4,216 words |
| `scripture-studies/old-testament/genesis/rooms/ch01.html` | 3,562 words |
| `scripture-studies/new-testament/john/rooms/ch01.html` | 3,541 words |

For comparison: a typical print magazine feature article runs 1,500–2,500 words. Your Church History page is longer than that *and* it's meant to be read on a phone. This isn't a style complaint — it's a genuine usability problem, especially for a tool meant to support a 90-minute commute where you're listening more than reading, and quick pre-drive or outage-time reference.

**Root cause:** content isn't chunked to match the site's own Tiered Study Card pattern (3 tiers, expand/collapse) — it looks like whole pages are written as one continuous scroll instead.

---

## 2. Font size — the actual numbers behind "I wish the words were bigger"

Your instinct is right, and I can show you exactly why it feels small:

- The root font-size defaults to 106.25% (≈17px) — reasonable.
- But the actual scripture passage text (`.passage-text`, the thing you're most often reading) is set to **0.89rem**, which nets out to roughly **14–15px** — smaller than the root, not larger.
- Most supporting content (cross-reference boxes, agree/diverge notes, reading-tools text) sits at **0.85rem or below**.
- There IS a working A-/A+ text-size control in the shared UI layer (`hub-ui.js`), which scales the root up to 120% — but it's a small, easy-to-miss control, and even at max size the passage text only reaches something like 17px, which is still modest for primary reading content.

**The fix isn't "raise the ceiling," it's "raise the floor."** Passage text should default closer to 1.05–1.15rem, not 0.89rem, so the *default* experience is comfortably readable without hunting for a control.

---

## 3. A bigger structural finding than what I flagged in Prompt 4

I need to correct something. In Prompt 4, I described the site as having two competing palettes — a warm "v19" system used almost everywhere, and a separate dark-slate theme used only in `tools/*.html`. **That was wrong, or at least incomplete**, and going through the actual files now shows the real picture:

- **All 111 HTML pages** — every index, every room, every tool — define their own primary design inline using the dark-slate palette (`#0f172a` background, gold/blue accents). This is the site's real, universal visual identity.
- **All 111 pages also load `hub-ui.css`**, which is the "v19" warm-paper/indigo/brass system — but only for specific shared overlay widgets: the zoom/focus modal, the reading ticker, the compare rail.
- **Result:** on every single page, the moment you trigger the zoom modal or certain reading-tool overlays, you get a jarring flash from dark-slate into a warm cream/ink panel that shares no visual DNA with the page it's sitting on top of.

So this isn't "two palettes, sprinkled across different sections" — it's **one palette for content, a different palette baked into shared utility overlays that appear on top of every page**. That's a more precise (and honestly more fixable) problem than what I described before: it means fixing `hub-ui.css`'s handful of overlay components fixes the whole site at once, rather than needing to migrate dozens of individual pages.

---

## 4. Navigation depth

Home → Scripture Studies → Old Testament → Genesis → Chapter room = **4 taps** to reach an actual passage. Reasonable for a reference library, less reasonable for "I want today's reading right now" — which is exactly the use case the Commute Engine (Prompt 8) is trying to solve with a dedicated shortcut. Worth making sure that shortcut actually exists prominently on the homepage once built, not just in the Commute Engine's own flow.

---

## 5. What's genuinely working well

- The room/chapter structure is consistent and predictable once you're inside it.
- The underlying "v19" type system (the shared CSS file) is thoughtfully built — real reading-comfort features (adjustable type, a genuine serif/sans pairing) exist, they're just not applied to the content people spend the most time reading.
- No dead links or broken structure found in the spot-checks I ran.

---

## 6. Recommended priority order

1. **Fix the floor, not the ceiling** — raise default passage text size site-wide. Single CSS variable change, highest impact for lowest effort.
2. **Resolve the overlay-palette clash** (§3) — also a contained fix, one file (`hub-ui.css`), fixes all 111 pages at once.
3. **Chunk long pages into the Tiered Card pattern** — biggest effort, biggest payoff for the "too wordy" complaint. Church History and the longer topic rooms are the worst offenders, good place to start.
4. **Layout experiments** — see the two mockups below. These are genuinely different visual directions, not just "same page, bigger font," per your request to see something more visually distinctive.
