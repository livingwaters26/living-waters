# Master Prompt Sheet — Everything Open, Ready to Paste

One place for every prompt across every tracked initiative. Bring `build-tracker.md` along with
whichever prompt you paste — I'll read current state from it and pick up correctly.

---

## 1. App Build (site merge, journal, multi-plan) — HIGHEST PRIORITY, IN PROGRESS

```
Continue the site/commute-companion merge from build-tracker.md section 5.
Start with step 1 (server.py v2). The plan schema conversion (step 0) is
already done at data/plans/bible-in-a-year.json.
```

This one prompt carries all 5 remaining steps (server merge, move commute-companion into the
site, journal save/archive system, the real 4x/week group study as a second plan, homepage links).
I'll work through them in order in one pass unless you say otherwise.

---

## 2. Bible Commentary Project — Revelation done, 26 NT books to go

```
Continue the Bible Commentary Project. Write full chapter-by-chapter
commentary on [BOOK], same depth and format as the Revelation commentary
(Movement / Key words / Typology-OT roots / Teaching note per chapter).
Stay neutral on contested interpretive questions. Redesign it into the
illuminated site page too, same as Revelation got. Update
workspace-build-docs/bible-commentary-master-tracker.md when done.
```

Fill in `[BOOK]`. Recommended order (jump the queue anytime for whatever you're actually
teaching/studying):
1. Matthew → Mark → Luke → John (the Gospels, most cross-linked-to material)
2. Acts
3. Romans → 1 Corinthians → 2 Corinthians → Galatians → Ephesians → Philippians → Colossians →
   1 Thessalonians → 2 Thessalonians (Pauline, canonical order)
4. 1 Timothy → 2 Timothy → Titus (Philemon already has a basic room, not full commentary yet)
5. Hebrews → James → 1 Peter → 2 Peter → 1 John → 2 John → 3 John → Jude

Can batch multiple short books in one prompt (e.g. "2 John, 3 John, and Jude — all three are one
chapter each").

---

## 3. Illuminated Redesign — 4 pages converted, 103 to go

```
Convert [PAGE PATH or SECTION] to the illuminated design system
(lib/illuminated.css / lib/illuminated.js). Pull real content from the
existing page — don't invent anything. Use the shared ilm- classes. Update
lib/CONVERSION-CHECKLIST.md and build-tracker.md when done.
```

Priority order already set in the checklist: Parables → Messianic Prophecy → Millennial Kingdom
→ Church History (fixes the wordiness problem too) → everything else. Full 107-item numbered
list with pre-written batch prompts is in `lib/CONVERSION-CHECKLIST.md` inside the site zip.

---

## 4. Topical Suite — 2 of 6 topics done

```
Build out [TOPIC] following the same template as Election/Predestination
and Sacraments/Ordinances in the Topical Suite — definition/scope,
scriptural cross-reference matrix, historical/denominational positions
presented fairly, historical development, pastoral & small group synthesis.
Stay neutral across traditions. Update the tracker when done.
```

Remaining topics: **Spiritual Warfare, Covenant Theology, Eschatology** (link to the existing
Millennial Kingdom module rather than duplicate), **Ethics**.

---

## 5. Small Group Curriculum — for your real 4x/week group

```
Build a full [N]-week small group curriculum for [TOPIC/BOOK], using the
Small Group Curriculum Builder template from Prompt 3 (Leader Guide,
Icebreaker, Discussion Questions, Participant Handout per session). Format
it as a plan in the new generalized plan schema (data/plans/) so it can be
loaded into Commute Companion alongside Bible in a Year.
```

This is probably worth doing early — it's both real content for your actual group AND the proof
that the generalized plan system (item 1) works with more than one plan.

---

## 6. Smaller standing items (quick wins when you have a short session)

```
Fix Prompt 4's period color table to match the real Jeff Cavins 12-period
scheme (Early World, Patriarchs, Egypt and Exodus, Desert Wanderings,
Conquest and Judges, Royal Kingdom, Divided Kingdom, Exile, Return,
Maccabean Revolt, Messianic Fulfillment, The Church) instead of the
invented one. Small, self-contained fix.
```

```
I meant [NAME] when I said "Armstrong" for the default commentator voices
in the Source & Perspective Engine (Prompt 12) — update that preset list.
```
*(You still need to tell me which Armstrong — flagged back in Prompt 12 and never resolved.)*

---

## How to use this sheet

- Bring **this file** to any future session as a quick menu.
- Bring **`build-tracker.md`** alongside it every time — it's what tells me actual current state.
- Pick whichever section matches your energy/time that day — nothing here has to happen in order
  except item 1's own 5 internal steps.
