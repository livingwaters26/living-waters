# Interactive Kings & Prophets Timeline Engine — Data Structure & Matrix

*Dates follow the standard conservative synchronization (approximating Thiele's chronology); co-regencies explain apparent overlaps. Treat exact years as the traditional scholarly range, not uncontested fact — this is flagged once here rather than on every row.*

---

## 1. Data Structure (per-king record schema)

```json
{
  "id": "king-ahab",
  "name": "Ahab",
  "kingdom": "Israel",
  "dynasty": "House of Omri",
  "reign_years": "874–853 BC",
  "regnal_length": 22,
  "capital": "Samaria",
  "evaluation": "did evil",
  "evaluation_note": "worse than all before him; married Jezebel, promoted Baal worship",
  "coregent_with": null,
  "foreign_alignment": ["Phoenicia (marriage alliance)", "conflict with Aram-Damascus"],
  "key_events": ["Elijah vs. prophets of Baal, Mt. Carmel", "Naboth's vineyard", "death at Ramoth-Gilead"],
  "prophets_contemporary": ["Elijah"],
  "narrative_refs": ["1 Kings 16:29–22:40"],
  "prophetic_book_refs": [],
  "timeline_period_id": 7
}
```
Each Judah record adds a `"davidic_line": true/false` flag (false only for Athaliah, the usurper). This schema plugs directly into the Timeline Parallel Card component from Prompt 4 — `evaluation` drives a color/icon state, `timeline_period_id` pulls the 12-period color from Prompt 4 §3.

---

## 2. Full Parallel Matrix — Divided Kingdom (931–586 BC)

### Northern Kingdom: Israel (fell to Assyria, 722 BC)

| King | Dynasty | Reign (BC) | Capital | Evaluation | Contemporary Prophets |
|---|---|---|---|---|---|
| Jeroboam I | House of Jeroboam | 931–910 | Shechem/Tirzah | Evil — golden calves at Bethel/Dan | — |
| Nadab | House of Jeroboam | 910–909 | Tirzah | Evil | — |
| Baasha | House of Baasha | 909–886 | Tirzah | Evil | Jehu son of Hanani |
| Elah | House of Baasha | 886–885 | Tirzah | Evil | — |
| Zimri | — (7 days) | 885 | Tirzah | Evil | — |
| Omri | House of Omri | 885–874 | Tirzah→Samaria | Evil — "worse than all before him" | — |
| Ahab | House of Omri | 874–853 | Samaria | Evil — Baal worship, Jezebel | Elijah |
| Ahaziah | House of Omri | 853–852 | Samaria | Evil | Elijah |
| Jehoram (Joram) | House of Omri | 852–841 | Samaria | Evil, but removed Baal pillar | Elisha |
| Jehu | House of Jehu | 841–814 | Samaria | Mixed — purged Baal worship, kept golden calves | Elisha |
| Jehoahaz | House of Jehu | 814–798 | Samaria | Evil | Elisha |
| Jehoash (Joash) | House of Jehu | 798–782 | Samaria | Evil, but honored dying Elisha | Elisha |
| Jeroboam II | House of Jehu | 793–753 | Samaria | Evil — but era of great territorial expansion | Jonah, Amos, Hosea |
| Zechariah | House of Jehu | 753 (6 mo.) | Samaria | Evil | Hosea |
| Shallum | — (1 mo.) | 752 | Samaria | Evil | Hosea |
| Menahem | — | 752–742 | Samaria | Evil — paid tribute to Assyria | Hosea |
| Pekahiah | — | 742–740 | Samaria | Evil | Hosea |
| Pekah | — | 752–732 (rival/overlap) | Samaria | Evil — allied with Aram against Judah | Hosea, Isaiah (from Judah) |
| Hoshea | — | 732–722 | Samaria | Evil, "yet not as the kings before him" | Hosea |

**722 BC — Fall of Samaria to Assyria (Shalmaneser V / Sargon II); Northern Kingdom ends (2 Kings 17).**

### Southern Kingdom: Judah (House of David, fell to Babylon, 586 BC)

| King | Reign (BC) | Evaluation | Contemporary Prophets |
|---|---|---|---|
| Rehoboam | 931–913 | Evil — high places tolerated | Shemaiah |
| Abijah (Abijam) | 913–911 | Evil | — |
| Asa | 911–870 | Good — removed idols, though high places remained | Azariah, Hanani |
| Jehoshaphat | 870–848 | Good — but allied with Ahab | Jehu son of Hanani |
| Jehoram (Joram) | 848–841 | Evil — married Athaliah, killed brothers | Elijah (letter) |
| Ahaziah | 841 | Evil | — |
| Athaliah (usurper, not Davidic) | 841–835 | Evil — seized throne, killed royal heirs | — |
| Joash (Jehoash) | 835–796 | Good early (under priest Jehoiada), evil later | Joel (disputed date) |
| Amaziah | 796–767 | Good, but incomplete; later prideful | — |
| Uzziah (Azariah) | 792–740 (coregency) | Good — but presumed to burn incense, struck with leprosy | Isaiah (early), Amos, Hosea |
| Jotham | 750–732 (coregency) | Good, though high places remained | Isaiah, Micah |
| Ahaz | 732–716 | Evil — child sacrifice, Assyrian alliance | Isaiah, Micah |
| Hezekiah | 716–687 | Good — major reform, Assyrian crisis survived (701 BC) | Isaiah, Micah |
| Manasseh | 687–642 | Evil — worst king of Judah; later repented (2 Chr. 33) | Nahum (likely) |
| Amon | 642–640 | Evil | — |
| Josiah | 640–609 | Good — major reform, Book of the Law found (622 BC) | Zephaniah, Jeremiah, Huldah |
| Jehoahaz | 609 (3 mo.) | Evil | Jeremiah |
| Jehoiakim | 609–598 | Evil — burned Jeremiah's scroll | Jeremiah, Habakkuk |
| Jehoiachin | 598–597 (3 mo.) | Evil; exiled to Babylon | Jeremiah, Ezekiel (in exile) |
| Zedekiah | 597–586 | Evil — rebelled against Babylon | Jeremiah, Ezekiel |

**586 BC — Fall of Jerusalem to Nebuchadnezzar; Temple destroyed; Babylonian Exile begins (2 Kings 25).**

---

## 3. Prophetic Integration Summary

| Prophet | Era | Primary Kingdom Context | Book |
|---|---|---|---|
| Elijah | Pre-classical | Israel (Ahab–Ahaziah) | (narrative only, 1 Kings 17–2 Kings 2) |
| Elisha | Pre-classical | Israel (Jehoram–Jehoash) | (narrative only, 2 Kings 2–13) |
| Jonah | Pre-exilic | Israel (Jeroboam II) | Jonah |
| Amos | Pre-exilic | Israel (Jeroboam II), from Judah | Amos |
| Hosea | Pre-exilic | Israel (Jeroboam II–fall) | Hosea |
| Isaiah | Pre-exilic | Judah (Uzziah–Hezekiah) | Isaiah |
| Micah | Pre-exilic | Judah (Jotham–Hezekiah) | Micah |
| Nahum | Pre-exilic | Judah (Manasseh, likely) | Nahum |
| Zephaniah | Pre-exilic | Judah (Josiah) | Zephaniah |
| Jeremiah | Pre-exilic → Exilic | Judah (Josiah–Zedekiah, into exile) | Jeremiah, Lamentations |
| Habakkuk | Pre-exilic | Judah (Jehoiakim, likely) | Habakkuk |
| Ezekiel | Exilic | Judah exiles, in Babylon | Ezekiel |
| Daniel | Exilic | Judah exiles, in Babylon/Persia | Daniel |
| Obadiah | Disputed (likely post-586) | Judah, re: Edom | Obadiah |
| Haggai | Post-exilic | Return community (Zerubbabel) | Haggai |
| Zechariah | Post-exilic | Return community (Zerubbabel) | Zechariah |
| Malachi | Post-exilic (late) | Return community | Malachi |
| Joel | Disputed | Judah, uncertain reign | Joel |

Narrative cross-references for the whole matrix: **1–2 Samuel** (united monarchy background), **1–2 Kings** (primary regnal source), **1–2 Chronicles** (parallel account, Judah-focused, includes theological commentary Kings omits).

---

## 4. Worked Timeline Parallel Card — Example 1: Ahab / Jehoshaphat (c. 870–853 BC)

**Left (Israel):** Ahab, House of Omri, Samaria, evaluation: evil (Baal worship via Jezebel). Key events: Mt. Carmel contest, Naboth's vineyard, death at Ramoth-Gilead.
**Right (Judah):** Jehoshaphat, evaluation: good, though militarily allied with Ahab (2 Chr. 18) — a alliance the text criticizes even amid his overall good evaluation.
**Connecting thread:** Elijah's ministry spans this exact window, confronting Ahab directly while Jehoshaphat's court in Judah remains comparatively faithful — the card's color-coded left/right contrast (evil-red tint vs. good-neutral tint) makes the moral divergence between the two thrones visually immediate.
**Cross-refs:** 1 Kings 16:29–22:40; 2 Chronicles 17–20.

## 5. Worked Timeline Parallel Card — Example 2: Hezekiah (c. 716–687 BC)

**Judah only (no Israel parallel — Northern Kingdom already fallen in 722 BC):** Hezekiah, evaluation: good — cultic reform, Passover reinstated, Assyrian siege under Sennacherib survived (701 BC, 2 Kings 18–19).
**Prophetic pairing:** Isaiah, whose court access and direct counsel to Hezekiah during the Assyrian crisis (Isaiah 36–39) is one of the clearest king-prophet interactions in the record.
**Card variant note:** since Israel no longer exists at this point, the component needs a "single-column" state (not just left/right) — worth flagging for the UI build in Prompt 4's card spec.
**Cross-refs:** 2 Kings 18–20; 2 Chronicles 29–32; Isaiah 36–39.

---

## 5. Build Note

Section 4/5 surfaces a UI gap in Prompt 4's Timeline Parallel Card spec: it needs a **single-kingdom mode** for the post-722 BC window (Hezekiah onward), not just the two-column layout. Worth folding back into the Prompt 4 component spec before implementation.
