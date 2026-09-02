# Sermon Builder & Small Group Curriculum Suite — Architecture & Templates

**Note on current state:** the `tools/sermon-builder.html` already in v25 is a *prompt-assembler* — it collects form inputs and outputs a text prompt for you to run through an AI elsewhere; it doesn't generate the sermon itself. This blueprint designs the actual generation engine and the new Small Group Curriculum Builder, plus shows one fully generated sample output for each so you can see the target quality before we wire it into the site.

---

## 1. Sermon Builder Engine

### 1.1 Workflow
1. **Input capture:** passage reference, sermon length (target minutes), audience type, tone preference.
2. **Exegetical synthesis pass:** pull structure/word-study/typology data from the Commentary Suite (Prompt 2 engine) for the selected passage — this is the key integration point, so the sermon is grounded in the same exegesis already built for that chapter, not generated fresh from scratch each time.
3. **Outline generation:** 3-point homiletical structure, each point tied directly to a textual unit.
4. **Enrichment layer:** illustration prompts, application targets, and suggested visual aids per point.
5. **Export:** clean markdown, copy-paste or downloadable `.md`/`.txt`.

### 1.2 Output Template
```
SERMON: [Title]
Passage: [Reference]
Big Idea: [One sentence]

I. [Point 1 heading] — [verse anchor]
   Commentary: [1–2 sentence exegetical note]
   Illustration prompt: [suggested angle, not scripted]
   Application: [specific, actionable]

II. [Point 2 heading] — [verse anchor]
    ...

III. [Point 3 heading] — [verse anchor]
    ...

Closing: [return to opening image / call to response]
```

### 1.3 Worked Sample — Luke 15:11–32 (Prodigal Son), 25-minute sermon, general congregation

**Big Idea:** The Father's grace runs to meet us before we've finished our confession.

**I. The Far Country (vv. 11–16) — the cost of self-sufficiency**
- Commentary: The son's request was culturally equivalent to wishing his father dead; the "far country" marks both geographic and relational distance.
- Illustration prompt: A modern picture of chasing independence at the cost of relationship — career, isolation, or addiction all work as contemporary parallels.
- Application: Name one place you're currently in a "far country" from God relationally, even if life looks fine externally.

**II. The Turning Point (vv. 17–20a) — repentance as return, not just regret**
- Commentary: "He came to himself" (v. 17) marks the shift from self-pity to honest self-assessment; the rehearsed speech shows genuine humility, not manipulation.
- Illustration prompt: The difference between regret (sorry I got caught) and repentance (sorry, and turning around) — a debt spiraling versus a debt confronted.
- Application: Repentance starts with an honest sentence, not a perfect one — invite the congregation to name that sentence privately.

**III. The Running Father (vv. 20b–24) — grace that precedes performance**
- Commentary: An elder Middle Eastern patriarch running was culturally undignified — the father absorbs the shame so the son doesn't have to carry it alone.
- Illustration prompt: A parent scanning a crowd for a lost child, the moment of spotting them before any explanation is given.
- Application: You are being watched for, not just tolerated — receive the welcome before you've finished explaining yourself.

**Closing:** Return to the "far country" image — ask where in the room someone might still be there, and invite them toward the road home tonight.

---

## 2. Small Group Curriculum Builder

### 2.1 Workflow
1. **Input capture:** passage/topic, number of weeks, group type (youth, young adult, general, men's/women's), commitment level (light/standard/deep-dive).
2. **Session architecture generation:** for each week — Leader Guide, Icebreaker, Discussion Questions, Participant Handout.
3. **Constraint handling:** shorter commitment levels compress discussion question count and simplify handout depth rather than cutting structure entirely.
4. **Export:** per-week markdown bundle, or full multi-week packet.

### 2.2 Per-Session Template
```
WEEK [N]: [Title]
Passage: [Reference]

LEADER GUIDE
- Session goal (1 sentence)
- Key background leader should know before teaching
- Pacing notes (suggested minutes per section)

ICEBREAKER
- [Low-commitment opening question or activity, thematically linked]

DISCUSSION QUESTIONS
1. [Observation question — what does the text say]
2. [Interpretation question — what does it mean]
3. [Application question — so what, now what]
4. [Optional deeper/theological question, standard+ commitment only]

PARTICIPANT HANDOUT
- Passage text reference
- 2–3 reflection questions for take-home
- One memory verse or key phrase
```

### 2.3 Worked Sample — Week 1 of a 4-week "Parables of Jesus" group series, standard commitment, general adult group

**WEEK 1: Seeds and Soil**
Passage: Matthew 13:1–23 (The Sower)

**Leader Guide**
- Session goal: help the group honestly assess what kind of "soil" they've been lately, not just analyze the parable academically.
- Background: first-century sowing preceded plowing, so all four soil types were a normal, expected part of any field — Jesus isn't describing an unusual scenario.
- Pacing: 5 min icebreaker, 10 min read + observation, 20 min discussion, 10 min handout/close.

**Icebreaker**
- "Think of a time you started something with a lot of enthusiasm that didn't last. What got in the way?"

**Discussion Questions**
1. What are the four soils, and what happens to the seed in each?
2. Why do you think Jesus explains this parable to the disciples privately but not to the crowd?
3. Which soil description makes you most uncomfortable right now, and why?
4. (Standard+) How does Isaiah 6:9–10, which Jesus quotes here, change how you read this parable's purpose?

**Participant Handout**
- Re-read Matthew 13:1–9, 18–23 this week.
- Reflection: What's currently crowding out your attention to God's word — worry, busyness, or something else?
- Memory phrase: "The one who received the seed that fell on good soil is the one who hears the word and understands it" (Matt. 13:23).

---

## 3. Commute Engine Integration Notes (for Prompt 8)

Both engines should output a **plain-text/audio-friendly variant** alongside the markdown: no tables, no nested bullets, short declarative sentences, and explicit verbal section markers ("Point one...", "Discussion question one...") so the Commute Engine (built in Prompt 8) can feed it to TTS cleanly without reformatting.

---

## 4. Build Recommendation

This is architecture + one sample each — enough to build the actual `tools/sermon-builder.html` and a new `tools/small-group-builder.html` as real generation tools (not just prompt-assemblers) when you're ready. Say the word and I'll write the actual HTML/JS for either one, matching the existing dark-theme card style already used in your `tools/` pages.
