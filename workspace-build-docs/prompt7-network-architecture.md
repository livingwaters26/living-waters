# Live-First Network Architecture Boundary — Blueprint

**Reality check before the architecture:** the site as it exists in v25 is a **fully static client-side build** — no backend, no API, no database. All data lives in JS globals (`window.V19_PASSAGES` from `data/passage-data.js`) loaded straight into the page. That's fine and fast for what it is, but it means the "Live Cloud Services" tier this prompt calls for (AI commentary generation, streaming, web-scraped sources) **doesn't exist yet as infrastructure** — this prompt is really asking for two things: (1) the boundary design (doable now, on paper), and (2) an actual backend to implement it against (a real decision point, flagged in §5).

---

## 1. Data Boundary & Storage Tiering

### Tier A — Local Persistent Cache (works fully offline)
| Data type | Storage | Notes |
|---|---|---|
| Core scripture text (all books) | IndexedDB, one object store per translation | Bundled at install/first-load, not fetched per-page like today's per-chapter JS files |
| User notes, highlights, saved plans | IndexedDB | Never leaves device unless user opts into sync (see §2.3) |
| Downloaded Commute audio | IndexedDB (Blob storage) or Cache API | Large binary — see compression notes §3 |
| Pre-cached 365-day reading set | IndexedDB | Populated by the One-Touch Pre-Cache protocol (§4) |
| Sermon Builder / Small Group outputs already generated | IndexedDB | Once generated, becomes local — no need to regenerate offline |

### Tier B — Live Cloud Services (requires connection)
| Data type | Source | Fallback when offline |
|---|---|---|
| Deep AI commentary generation (new, not-yet-cached passages) | API call to generation backend | Show last-cached version if any; otherwise "available when back online" state, never a silent failure |
| Web-scraped/aggregated sources | External fetch | Same fallback pattern |
| On-demand streaming (audio not yet downloaded) | CDN/streaming endpoint | Falls back to text-only reading mode |

**Boundary rule:** nothing in Tier B should be a hard dependency for reading, studying, or listening to anything the user has already visited or explicitly pre-cached. Tier B only gates *new* content generation.

### 1.1 Local Schema Sketch (IndexedDB)
```js
// db: studyhub-local, version 1
{
  passages:      { keyPath: "ref" },           // e.g. "john-1", full text + metadata
  notes:         { keyPath: "id", indexes: ["ref", "createdAt"] },
  commuteAudio:  { keyPath: "ref" },            // blob + duration + generatedAt
  precacheQueue: { keyPath: "day" },            // 365-day plan tracking
  syncQueue:     { keyPath: "id", indexes: ["status"] }  // pending outbound changes
}
```

---

## 2. Caching & Sync Protocols

### 2.1 Reconnection Sync
On regaining connectivity: (1) flush `syncQueue` (user notes/highlights created offline) to the backend first — user data takes priority, (2) check for any `precacheQueue` items still pending, (3) only then resume any deferred AI-generation requests. This ordering avoids wasting the first moments of a spotty connection on non-critical fetches.

### 2.2 Conflict Handling
Notes/highlights are last-write-wins by timestamp, with a lightweight local "conflict copy" kept (not silently discarded) if the same note was edited on two devices offline — surfaced to the user rather than resolved invisibly.

### 2.3 Sync Is Opt-In
Given this is a personal study tool, cross-device sync of notes should be an explicit opt-in (likely tied to an account system that doesn't currently exist either — another point for §5), not assumed. Local-only should remain a fully supported mode indefinitely, not just a fallback state.

---

## 3. Payload Compression & Lazy-Loading

- **Text chunking:** scripture and commentary text loads per-chapter (already the site's pattern — e.g. `rooms/ch01.html`), so no change needed there; the improvement is caching those chunks in IndexedDB after first fetch instead of re-requesting.
- **Compression:** gzip/brotli at the transport layer (server-config concern, not app-code) for anything fetched live; audio uses a compressed codec (e.g. Opus/AAC) at a speech-appropriate bitrate (32–48kbps mono is plenty for spoken commentary, dramatically smaller than music-grade audio).
- **Lazy-loading:** large theological text blocks (e.g. full commentary deep-dives) load a preview/first-tier immediately, defer tiers 2–3 until the user expands them (ties directly into the Tiered Study Card's expand/collapse mechanic from Prompt 4 — the UI and network layer should share this boundary).

---

## 4. Commute Pre-Fetch Engine — "One-Touch Pre-Cache" Protocol

1. **Trigger:** user taps a single "Pre-Cache for Commute" action, only enabled on Wi-Fi (checked via `navigator.connection.type` where available, with a manual override since that API isn't universally supported).
2. **Payload assembled:** full 365-day reading plan text + generated audio commentary + any sermon/small-group notes flagged for the trip.
3. **Progress UI:** a visible progress state (this is a meaningfully large download — audio for a year of readings — so silent background caching would be confusing; the user should see it happening and be able to pause/resume).
4. **Storage confirmation:** once complete, an explicit "Ready for offline" badge/state, so Driver Mode never silently fails mid-drive from an incomplete cache — this ties directly to Driver Mode's no-silent-failure requirement from Prompt 4.
5. **Staleness handling:** if the underlying commentary/audio is later regenerated or updated, the cached copy is marked stale but still usable — never auto-deleted while offline, only refreshed opportunistically next time Wi-Fi is available.

---

## 5. Open Infrastructure Decision (needs your input)

This blueprint assumes a backend that **doesn't exist yet** in the current build. Before any of Tier B or the sync protocol can actually be implemented, you'll need to decide:
- **Hosting/backend approach:** a real API server (Node/Python/etc.) + database, or a serverless/BaaS approach (e.g. Firebase, Supabase)?
- **AI generation backend:** how "Deep AI Commentary Generation" actually gets served live — your own API key/backend calling a model, or something else?
- **Accounts:** does cross-device sync require user accounts/auth, and do you want that scope in this build at all, or should this stay a single-device, local-only tool for now?

This is the first prompt in the queue that can't be fully "delivered" as pure content/architecture — it's a genuine product decision that changes what Prompts 8–11 (which build on this network layer, especially the Commute Engine) can actually assume.
