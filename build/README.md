# build/ — project tooling

**These are build-time scripts, not part of the app.** Nothing here ships to the
reader; nothing here is linked from any page. They exist to make adding the
remaining 65 books fast and safe.

> Note: an earlier plan put these in `tools/`. That was wrong — `tools/` is the
> app's own user-facing tools section (Sermon Builder, Commute Companion, Plan
> Builder). Build scripts live here instead so they never appear as app pages.

Requires Node. No npm install, no dependencies.

---

## Files

| File | Purpose |
|---|---|
| `books.js` | Canonical registry of all 66 books — chapter counts, KJV verse totals, slugs, testament, period mapping |
| `build-book-page.js` | Generates a complete `panorama.html` for any book from the chapter data |
| `validate.js` | Structural + reference validation of all scripture data |

---

## The workflow for adding a book

1. **Fetch the text** from the verified public-domain KJV source:
   ```
   https://raw.githubusercontent.com/midvash/bible-data/main/versions/en/kjv/books/<Book>.json
   ```
   Most books arrive in one fetch; the giants (Psalms, Isaiah, Jeremiah, Ezekiel)
   take 2–3.

2. **Write chapter records** into `data/panorama-data.js` in the established shape:
   ```js
   window.LW_CHAPTERS["exodus-1"] = {
     book: "Exodus", chapter: 1, title: "Israel Oppressed in Egypt",
     period: "egypt-exodus",
     verses: [
       { n: "1", t: { KJV: "Now these are the names..." } },
       ...
     ]
   };
   ```
   The `period` value must match `books.js` for that chapter.

3. **Generate the page:**
   ```
   node build/build-book-page.js exodus
   ```

4. **Validate:**
   ```
   node build/validate.js exodus
   ```
   Exit code 0 = clean. Non-zero = errors that must be fixed before checkpointing.

5. **Link it** from the relevant testament index page.

---

## Commands

```bash
node build/build-book-page.js genesis        # one book
node build/build-book-page.js genesis --dry  # preview, write nothing
node build/build-book-page.js --all          # every book that has data

node build/validate.js                       # whole store + progress summary
node build/validate.js exodus                # one book
```

---

## What the generator produces

Everything is derived from real data — nothing hardcoded:

- chapter sections with correct period tag and colour, from `books.js`
- shape-view cells sized by **actual** verse counts (unwritten chapters render
  as dashed placeholders automatically)
- persistent mini-TOC listing only chapters that exist
- scroll-spy highlighting, zoom controls, word-colouring legend
- the intro chip flips between "In Progress — N of M" and "Complete — All M
  Chapters" on its own

Add a chapter to the data, re-run the generator, and the page updates itself.

---

## What the validator checks

**Hard errors** (exit 1):
- chapter numbers beyond a book's real chapter count
- `chapter` field disagreeing with its key
- verse numbers out of sequence
- empty verse text
- placeholder text (`TODO`, `lorem ipsum`, etc.) left behind
- missing required fields

**Warnings** (exit 0, but worth a look):
- gaps in chapter coverage
- period disagreeing with the registry
- completed book whose verse total differs from the standard KJV figure

### One deliberate exception
Per-chapter verse counts are **not** checked against a reference table.
Genesis 1 intentionally carries 2:1–3 (the Sabbath) into it, so its chapter
boundaries differ from standard versification while the book total stays
correct at 1,533. The validator understands `"2:1"`-style cross-chapter verse
labels and treats them as intentional. Book totals and structural integrity are
the checks that actually matter.
