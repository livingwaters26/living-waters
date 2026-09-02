# Commentary Suite & Historical Arc Engine — Architectural Blueprint

This defines the structure for the NT & priority-OT commentary system (Genesis, Exodus, Isaiah, Jeremiah, Ezekiel, Zechariah, Psalms, Proverbs, plus the full NT). Full verse-by-verse commentary across all of these books is a multi-book-length undertaking — this blueprint gives you the template and engine design, plus one fully worked chapter as a proof of concept, so we can build out the rest book-by-book or chapter-by-chapter in follow-up passes.

---

## 1. Per-Book Commentary Template

Every book/chapter "room" in the suite follows this fixed structure:

**A. Literary Structure & Outline**
- Genre classification (narrative, law, wisdom, prophecy, epistle, apocalyptic, etc.)
- Macro-structure (major sections/movements)
- Chapter-by-chapter outline with unit headings

**B. Verse-by-Verse / Pericope Exegesis**
- Original language word studies (Hebrew/Greek), keyed to Strong's or equivalent numbering
- Grammatical/syntactical notes where they affect meaning
- Historical-cultural context per unit

**C. Typology & Covenantal Development**
- OT: forward-looking typology, covenant markers (Abrahamic, Mosaic, Davidic, New)
- NT: fulfillment citations, covenant inauguration/expansion

**D. Cross-Reference Mapping**
- Canonical links (OT↔NT, prophecy↔fulfillment, thematic parallels)

---

## 2. Salvation History Arc Framework

Five master arcs, each mapped to a timeline band and anchor books:

| Arc | Timeline Band | Anchor Books | Key Covenant Markers |
|---|---|---|---|
| Patriarchal Era | Creation–Egypt entry | Genesis | Adamic, Noahic, Abrahamic |
| Exodus & Wilderness | Egypt–Conquest | Exodus | Mosaic/Sinai |
| Monarchical & Divided Kingdom | Judges–Exile | Psalms, Proverbs (wisdom era); historical books | Davidic |
| Exile & Post-Exilic Return | Exile–Return | Jeremiah, Ezekiel, Zechariah | Covenant discipline & restoration promise |
| Messianic Fulfillment & Early Church | Incarnation–Apostolic era | NT (Gospels → Epistles → Revelation) | New Covenant |

Each arc entry in the suite will carry: historical timeline placement, dominant theological question of the era, and the covenant thread carried forward from the prior arc.

---

## 3. 365-Day Chronological Timeline Alignment

Each book/chapter room will carry metadata tags: `era`, `approx-date-range`, `day-range` (mapped to a standard 365-day chronological reading plan), and `arc-id`, so the frontend can cross-link a passage to (a) its place in canonical order, (b) its place in chronological/historical order, and (c) its salvation-history arc — enabling the existing cross-reference mechanics used elsewhere on the site (as in the Messianic Prophecy and Millennial Kingdom modules already built).

---

## 4. Worked Example: Genesis 1 (Proof of Concept)

**A. Literary Structure**
- Genre: Cosmological narrative / creation account
- Structure: Seven-day framework — days 1–3 (forming/spaces), days 4–6 (filling/inhabitants), day 7 (rest) — a deliberate two-panel symmetry.

**B. Key Word Studies**
- *bara* (ברא) — "create," used exclusively of God in the OT, denoting origination without pre-existing material (contrast *asah*, "make/fashion," used later in the chapter).
- *tohu wa-bohu* (תֹהוּ וָבֹהוּ) — "formless and void" (1:2), describing the pre-creation state addressed by the forming/filling structure.
- *tselem* (צֶלֶם) — "image" (1:26–27), foundational to biblical anthropology and human dignity.

**C. Typology & Covenant Development**
- The Sabbath rest of day 7 establishes a creation ordinance later codified in the Mosaic covenant (Exodus 20:8–11) and reinterpreted eschatologically (Hebrews 4:9–10).
- "Let there be light" (1:3) is picked up typologically in 2 Corinthians 4:6 as a pattern for new-creation illumination.

**D. Cross-Reference Mapping**
- John 1:1–3 — creation through the Word, direct NT theological echo.
- Psalm 33:6–9 — creation by divine speech, poetic reflection on Genesis 1.
- Colossians 1:16 — Christ as agent of creation.
- Revelation 21:1 — new heavens and new earth, the eschatological bookend to Genesis 1.

---

## 5. Build Sequencing Recommendation

Given the scope, I'd suggest we build this out in book-sized or chapter-sized batches rather than all at once — e.g., Genesis 1–11 as a batch, then 12–50, then move to Exodus, etc. Let me know which book or chapter range you want fully exegeted next and I'll produce it in the same format as the Genesis 1 example above.
