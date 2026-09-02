# Dynamic Source & Perspective Expansion Engine

**Infrastructure note (consolidating, not repeating from scratch):** this is the most backend-dependent module yet — it needs a vector database, an embeddings pipeline, and a web-crawling service, none of which exist today. This isn't a new finding; it's the same open backend decision from Prompt 7, now with a fuller picture of what it needs to support. Worth resolving that decision with this full picture in view rather than in the abstract.

**One naming flag before the schema:** the prompt lists "Armstrong" among the default curated voices alongside Spurgeon, Luther, Calvin, Henry. That surname is ambiguous — it could mean several different commentators, including at least one (Herbert W. Armstrong, Worldwide Church of God) whose theology sits well outside historic Christian orthodoxy and wouldn't belong in the same "classic voices" tier as Calvin/Luther/Spurgeon/Henry. I didn't want to guess and build a config around the wrong person — tell me who you meant and I'll slot them in correctly.

---

## 1. Theological Lens Switcher — Configuration Schema

```json
{
  "lens_config": {
    "mode": "preset" | "custom",
    "preset_id": "reformed-covenantal",
    "base_layer_voices": ["calvin", "luther", "spurgeon", "matthew-henry"],
    "custom_selection": ["calvin", "wesley", "chrysostom"],
    "comparative_mode": false
  }
}
```

### Preset Tradition Filters
| Preset | Example voices included |
|---|---|
| Patristic / Early Church | Augustine, Chrysostom, Athanasius, Origen (with commentary-tier caveats where his views were later judged heterodox on specific points) |
| Reformed / Covenantant | Calvin, Matthew Henry, the Westminster divines |
| Arminian / Wesleyan | Wesley, Arminius, Adam Clarke |
| Dispensational / Futurist | Scofield, Ryrie-tradition commentary |
| Historical-Academic | Modern critical-historical commentators, cited with full bibliographic attribution rather than folded in as an anonymous "voice" |

### Custom Blend Selector
Granular multi-select UI — each author toggled independently regardless of preset, with a visible indicator when a user's custom blend mixes traditions that substantively disagree (e.g., selecting both a strict Dispensationalist and a Covenant theologian) — not to block the combination, just to flag it so the resulting output's internal tension is expected rather than confusing.

---

## 2. Dynamic Source Ingestion Pipeline (RAG)

### 2.1 Teacher Source Vault (PDF Uploads)
```
Upload → text extraction → chunking (≈500–800 tokens/chunk, paragraph-aware boundaries)
       → embedding generation → vector store, tagged with:
         { source_id, author, title, tradition_tag (user-assigned, optional),
           upload_date, page_ref_per_chunk }
```
**Licensing note:** anything a user uploads here is their own responsibility/license to use — the system just indexes it locally for their own retrieval, not for redistribution to other users (relevant if this ever becomes multi-user rather than single-device).

### 2.2 Web Commentary Crawler
```
URL submitted → robots.txt / ToS check → fetch → extract main content
             → chunk + embed + index, same schema as above, plus { source_url, crawl_date }
```
**Legal/copyright boundary — important, not optional:** for public-domain sources (Calvin, Luther, Matthew Henry, Spurgeon — all long out of copyright), full-text ingestion and display is fine. For **modern, copyrighted commentary sites**, the crawler should index for retrieval/search purposes only and the system should generate short paraphrased excerpts with attribution and a link back to the original — not store or redisplay full copyrighted text. This mirrors standard fair-use-respecting RAG practice and avoids building a tool that quietly mirrors other publishers' copyrighted commentary.

---

## 3. Grounding & Synthesis Rules

**Priority rule when custom/comparative mode is active:**
```
IF custom_mode == true AND relevant_chunks_found > 0:
    generation MUST cite and prioritize ingested source chunks
    over the model's general training-data knowledge of that passage
ELSE:
    fall back to default base-layer voices + general knowledge,
    clearly labeled as such (never blend silently)
```
This is a real prompt-engineering rule, not just a UI toggle — it needs to be enforced in whatever system prompt drives the generation step (ties directly to Prompt 7's backend/AI-generation decision), and any output should be labeled with which sources actually grounded it, so it's never ambiguous whether a given point came from an uploaded PDF, a crawled site, or the model's general knowledge.

---

## 4. Comparative Commentary Mode

A new card variant — extends the Tiered Study Card (Prompt 4) rather than inventing a fourth card type:

```
COMPARATIVE VIEW: [Passage]

┌─────────────┬─────────────┬─────────────┐
│ Luther       │ Wesley       │ [Uploaded PDF]│
├─────────────┼─────────────┼─────────────┤
│ [excerpt/    │ [excerpt/    │ [excerpt/    │
│  paraphrase] │  paraphrase] │  paraphrase] │
└─────────────┴─────────────┴─────────────┘

Synthesis note: [1-2 sentences on where they agree/diverge —
generated only from what's actually in the compared sources,
not the model inventing a false consensus]
```
Mobile behavior: stacks vertically rather than side-by-side columns below a certain width, consistent with the responsive rules already established for Prompt 4's card system generally.

---

## 5. Master System Status — All 11 Original Prompts + This Add-On

Every prompt in the queue now has a delivered architecture/content pass. Worth being precise about what that does and doesn't mean:

**What's true:** every module has a real spec, real sample content, and (where relevant) real data — the reading plan JSON, the kings/prophets matrix, the parables catalog, etc. Nothing here was hand-waved.

**What's not yet true:** almost none of it is built into the actual live site files. This has been architecture and content generation throughout, not implementation. The gap between "specced" and "shipped" is still the whole remaining project.

**What's still genuinely undecided, blocking real implementation:**
1. Backend hosting (Prompt 7, now also load-bearing for this module's RAG pipeline)
2. Native app vs. website scope for the commute piece specifically (Prompt 8)
3. Prompt 4's period color table still needs the correction to match the real Jeff Cavins scheme

Those three decisions are the actual bottleneck now, not more specification. The next useful move is probably picking one small, concrete piece (e.g., fixing the color table, or building the actual Sermon Builder generation tool) and shipping it into the real site files, rather than adding more architecture on top of an already-thorough set of plans.
