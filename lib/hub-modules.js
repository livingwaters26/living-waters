/* ============================================================
   Study Hub v19 — feature modules
   Load order: passage-data.js → hub-ui.js → hub-modules.js

   Reads window.V19_PASSAGES. A page opts in with:
     <body data-passage="john-1">
   Pages with no data-passage still get the ticker (running a
   general rotation) and the type control; the rail and compare
   view simply stay out of the way.
   ============================================================ */
(function () {
  "use strict";

  var V19 = window.V19 = window.V19 || {};
  var DATA = window.V19_PASSAGES || {};
  var LICENSED = window.V19_LICENSED || [];

  /* ---- which passages is this page about? ------------------ */
  function pageKeys() {
    var attr = document.body.getAttribute("data-passage") || "";
    return attr.split(",").map(function (s) { return s.trim(); })
               .filter(function (s) { return s && DATA[s]; });
  }
  function primary() { var k = pageKeys(); return k.length ? DATA[k[0]] : null; }

  /* ---- research link, matching the v18 offline convention --- */
  function researchLink(text, query) {
    var url = "https://www.google.com/search?q=" + encodeURIComponent(query);
    if (navigator.onLine === false) {
      return '<span class="v19-offline-note">' + esc(text) +
             ' — content not available right now</span>';
    }
    return '<a class="research-link" href="' + url + '" target="_blank" rel="noopener">' +
           esc(text) + ' <span class="v19-offline-note">(opens in browser — needs internet)</span></a>';
  }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  /* ==========================================================
     A. FOOTER TICKER
     ========================================================== */

  var GENERAL_TICKS = [
    { src: "crossref", text: "Tip: tap any content box to open it full screen. Tap the ribbon tabs on the right rail to see where the traditions split." },
    { src: "fathers", text: "The Church Fathers rarely agree with each other as neatly as later summaries suggest — where they diverge, this app says so." },
    { src: "scofield", text: "Scofield notes in this app are summaries of the 1917 positions written for the app, not transcriptions of Scofield's exact wording." }
  ];

  function buildTicker() {
    var rec = primary();
    var derived = rec ? null : derivePageRecord();
    var items = rec ? rec.ticker.slice() : (derived ? derived.ticker : GENERAL_TICKS.slice());

    var bar = document.createElement("div");
    bar.className = "v19-ticker";
    bar.setAttribute("aria-label", "Tradition perspectives on this passage");

    var key = document.createElement("div");
    key.className = "v19-ticker-key";
    key.textContent = rec ? rec.ref : (derived && derived.ref ? derived.ref : "Study Hub");
    bar.appendChild(key);

    var win = document.createElement("div");
    win.className = "v19-ticker-window";
    var track = document.createElement("div");
    track.className = "v19-ticker-track";

    /* duplicated once so the loop has no visible seam */
    items.concat(items).forEach(function (it) {
      var s = document.createElement("span");
      s.className = "v19-tick";
      s.innerHTML = '<span class="v19-tick-src ' + esc(it.src) + '">' +
                    esc(labelFor(it.src)) + '</span><span>' + esc(it.text) + '</span>';
      track.appendChild(s);
    });
    win.appendChild(track);
    bar.appendChild(win);

    /* --- controls --- */
    var tools = document.createElement("div");
    tools.className = "v19-ticker-tools";

    tools.appendChild(btn("⏸", "Pause the ticker", function (e) {
      var p = bar.classList.toggle("paused");
      e.currentTarget.textContent = p ? "▶" : "⏸";
      e.currentTarget.title = p ? "Resume the ticker" : "Pause the ticker";
    }));
    tools.appendChild(btn("A−", "Smaller text", function () { V19.typeScale.nudge(-1); }));
    tools.appendChild(btn("A+", "Larger text", function () { V19.typeScale.nudge(1); }));
    if (rec) tools.appendChild(btn("⇄", "Compare translations", function () { V19.openCompare(); }));

    bar.appendChild(tools);
    document.body.appendChild(bar);
    document.body.classList.add("v19-ticker-on");

    /* hover on desktop, tap on tablet */
    bar.addEventListener("mouseenter", function () { bar.classList.add("paused"); });
    bar.addEventListener("mouseleave", function () {
      if (!bar.dataset.locked) bar.classList.remove("paused");
    });
    win.addEventListener("click", function () {
      bar.dataset.locked = bar.dataset.locked ? "" : "1";
      bar.classList.toggle("paused", !!bar.dataset.locked);
    });

    /* longer lists need longer to travel */
    track.style.animationDuration = Math.max(40, items.length * 11) + "s";
  }

  function labelFor(src) {
    return { fathers: "Fathers", catholic: "Catholic", protestant: "Protestant",
             scofield: "Scofield 1917", crossref: "Cross-ref" }[src] || src;
  }

  /* ---- derive ticker content straight from THIS page's own markup,
     for the ~95% of pages that don't have a hand-authored passage-data.js
     record. Reuses whatever the page already says (tldr lines, history
     callouts, cross-reference boxes) rather than inventing anything. ---- */
  function stripLabel(el) {
    var clone = el.cloneNode(true);
    var label = clone.querySelector(".history-callout-label, .cross-ref-label, .info-banner-label");
    if (label) label.remove();
    return clone.textContent.replace(/\s+/g, " ").trim();
  }

  function derivePageRecord() {
    var items = [];
    var h1 = document.querySelector(".header h1");
    var ref = h1 ? h1.textContent.trim() : null;

    document.querySelectorAll(".tldr").forEach(function (el) {
      var t = el.textContent.replace(/\s+/g, " ").trim();
      if (t) items.push({ src: "crossref", text: t });
    });
    document.querySelectorAll(".cross-ref-box").forEach(function (el) {
      var t = stripLabel(el);
      if (t) items.push({ src: "crossref", text: t });
    });
    document.querySelectorAll(".history-callout").forEach(function (el) {
      var t = stripLabel(el);
      if (t) items.push({ src: "fathers", text: t });
    });
    document.querySelectorAll(".info-banner").forEach(function (el) {
      var t = stripLabel(el);
      if (t) items.push({ src: "crossref", text: t });
    });

    if (!items.length) return null;
    /* cap it so the loop doesn't get sluggish on content-heavy pages */
    return { ref: ref, ticker: items.slice(0, 8) };
  }

  function btn(label, title, fn) {
    var b = document.createElement("button");
    b.type = "button"; b.textContent = label; b.title = title;
    b.setAttribute("aria-label", title);
    b.addEventListener("click", fn);
    return b;
  }

  /* ==========================================================
     B. COMPARE TRANSLATIONS
     Verses stay on one row across every column, so a horizontal
     read shows the difference immediately. Words that differ from
     the leftmost column are marked.
     ========================================================== */

  V19.openCompare = function (key) {
    var rec = key ? DATA[key] : primary();
    if (!rec) return;

    var ids = Object.keys(rec.translations);          /* e.g. ["ASV","KJV"] */
    var cols = ids.length + LICENSED.length;

    /* Columns are written out as a literal rather than through a CSS
       variable inside repeat(), which some Android WebViews refuse.
       Narrow screens get a scroll floor instead of squeezed columns. */
    var narrow = window.innerWidth < 720;
    var colCss = (narrow ? "44px " : "56px ") +
                 "repeat(" + cols + ", minmax(" + (narrow ? "150px" : "0") + ", 1fr))";

    var html = '<div class="v19-compare-grid" style="grid-template-columns:' + colCss +
               (narrow ? ';min-width:' + (44 + cols * 150) + 'px' : '') + '">';
    html += '<div class="v19-cmp-head"></div>';
    ids.forEach(function (id) { html += '<div class="v19-cmp-head">' + esc(id) + '</div>'; });
    LICENSED.forEach(function (L) { html += '<div class="v19-cmp-head">' + esc(L.id) + '</div>'; });

    rec.verses.forEach(function (v) {
      html += '<div class="v19-cmp-vn">' + v + '</div>';
      var base = tokens(rec.translations[ids[0]][v] || "");
      ids.forEach(function (id, i) {
        var text = rec.translations[id][v] || "";
        html += '<div class="v19-cmp-cell">' + (i === 0 ? esc(text) : markDiff(text, base)) + '</div>';
      });
      LICENSED.forEach(function (L) {
        html += '<div class="v19-cmp-cell v19-cmp-linkout">' +
                (v === rec.verses[0]
                  ? researchLink("Read " + L.id + " on Bible Gateway", rec.ref + " " + L.id + " Bible Gateway")
                  : "") + '</div>';
      });
    });
    html += '</div>';

    if (rec.diffNote) {
      html += '<div class="v19-cmp-note"><b>What changes, and why it matters.</b> ' + esc(rec.diffNote) + '</div>';
    }
    html += '<div class="v19-cmp-note">ASV (1901) and KJV are public domain and printed here in full. ' +
            LICENSED.map(function (L) { return esc(L.id); }).join(" and ") +
            ' are under copyright, so this app links to them rather than reproducing them. ' +
            'Those links need internet; everything else on this screen works offline.</div>';

    V19.openSheet("Compare — " + rec.ref, html);
  };

  function tokens(s) {
    var m = {}, w = s.toLowerCase().replace(/[^a-z\s'-]/g, "").split(/\s+/);
    w.forEach(function (x) { if (x) m[x] = true; });
    return m;
  }
  function markDiff(text, base) {
    return text.split(/(\s+)/).map(function (piece) {
      if (!piece.trim()) return piece;
      var bare = piece.toLowerCase().replace(/[^a-z'-]/g, "");
      if (bare && !base[bare]) return "<mark>" + esc(piece) + "</mark>";
      return esc(piece);
    }).join("");
  }

  /* ==========================================================
     C. INSIGHT RAIL + CONSENSUS RIBBONS
     ========================================================== */

  function buildRail() {
    var rec = primary();
    if (!rec) return;

    var rail = document.createElement("aside");
    rail.className = "v19-rail";
    rail.setAttribute("aria-label", "Contextual insight");

    var handle = document.createElement("button");
    handle.className = "v19-rail-handle";
    handle.type = "button";
    handle.textContent = "Insight";
    handle.setAttribute("aria-expanded", "false");
    handle.addEventListener("click", function () {
      var open = rail.classList.toggle("open");
      handle.setAttribute("aria-expanded", String(open));
      handle.textContent = open ? "Close" : "Insight";
    });
    rail.appendChild(handle);

    var head = document.createElement("div");
    head.className = "v19-rail-head";
    head.innerHTML = '<span class="v19-rail-ref">' + esc(rec.ref) + '</span>';
    rail.appendChild(head);

    var body = document.createElement("div");
    body.className = "v19-rail-body";
    body.innerHTML = railHTML(rec);
    rail.appendChild(body);

    document.body.appendChild(rail);
    wireRail(body, rec);
  }

  function railHTML(rec) {
    var c = rec.consensus;
    var h = '<h3>Doctrinal alignment</h3>';

    h += '<div class="v19-ribbons" role="group" aria-label="Consensus across six traditions">';
    c.traditions.forEach(function (t, i) {
      h += '<button class="v19-ribbon" type="button" data-level="' + t.level + '" data-i="' + i + '" ' +
           'aria-expanded="false" title="' + esc(t.name) + ' — ' + t.level + '">' + esc(t.short) + '</button>';
    });
    h += '</div>';

    h += '<div class="v19-verdict" data-level="' + c.level + '">' + esc(c.verdict) + '</div>';
    c.traditions.forEach(function (t, i) {
      h += '<div class="v19-breakdown" data-i="' + i + '" hidden><b>' + esc(t.name) + '</b> — ' + esc(t.note) + '</div>';
    });

    h += '<h3>Classic study notes</h3>';
    h += '<button class="v19-btn" type="button" data-open-scofield style="width:100%">Scofield Notes (1917)</button>';

    h += '<h3>Compare</h3>';
    h += '<button class="v19-btn" type="button" data-open-compare style="width:100%">Compare translations</button>';

    h += '<h3>Discover</h3>';
    rec.cards.forEach(function (card, i) {
      h += '<div class="v19-card" data-card="' + i + '">' +
           '<span class="v19-card-kind">' + esc(card.kind) + '</span>' +
           (card.search ? researchLink(card.text, card.search) : esc(card.text)) +
           '<br><button class="v19-card-save" type="button">Save to Thought Organizer</button></div>';
    });
    return h;
  }

  function wireRail(body, rec) {
    body.querySelectorAll(".v19-ribbon").forEach(function (r) {
      r.addEventListener("click", function () {
        var i = r.dataset.i;
        var panel = body.querySelector('.v19-breakdown[data-i="' + i + '"]');
        var open = panel.hidden;
        body.querySelectorAll(".v19-breakdown").forEach(function (p) { p.hidden = true; });
        body.querySelectorAll(".v19-ribbon").forEach(function (b) { b.setAttribute("aria-expanded", "false"); });
        panel.hidden = !open;
        r.setAttribute("aria-expanded", String(open));
      });
    });

    var sco = body.querySelector("[data-open-scofield]");
    if (sco) sco.addEventListener("click", function () { V19.openScofield(); });

    var cmp = body.querySelector("[data-open-compare]");
    if (cmp) cmp.addEventListener("click", function () { V19.openCompare(); });

    body.querySelectorAll(".v19-card-save").forEach(function (b) {
      b.addEventListener("click", function () {
        var card = rec.cards[b.closest(".v19-card").dataset.card];
        V19.saveThought({
          text: card.text,
          kind: card.kind,
          ref: rec.ref,
          source: "Insight rail"
        });
        b.textContent = "Saved ✓";
        b.classList.add("saved");
      });
    });
  }

  /* ---- shared inbox with the Thought Organizer ------------- */
  V19.saveThought = function (item) {
    var key = "v19.thoughts";
    var list = [];
    try { list = JSON.parse(V19.store.get(key, "[]")) || []; } catch (e) { list = []; }
    item.id = "t" + Date.now() + Math.random().toString(36).slice(2, 6);
    item.at = new Date().toISOString();
    item.tags = item.tags || [];
    list.push(item);
    V19.store.set(key, JSON.stringify(list));
    return item;
  };

  /* ==========================================================
     D. SCOFIELD 1917 LAYER
     ========================================================== */

  V19.openScofield = function (key) {
    var rec = key ? DATA[key] : primary();
    if (!rec || !rec.scofield) return;
    var s = rec.scofield;

    var h = '<div class="v19-tabs" role="tablist">' +
            '<button class="v19-tab" role="tab" aria-selected="false" data-pane="app">This app\'s commentary</button>' +
            '<button class="v19-tab" role="tab" aria-selected="true" data-pane="sco">Scofield 1917</button>' +
            '</div>';

    h += '<div data-pane-body="sco"><div class="v19-scofield" style="margin-top:14px">' +
         '<span class="v19-badge">1917 Scofield Reference — summarised</span>' +
         '<p>' + esc(s.note) + '</p>';
    if (s.chain && s.chain.length) {
      h += '<div class="v19-chain">Chain reference: ' + s.chain.map(esc).join(" · ") + '</div>';
    }
    if (s.caution) {
      h += '<div class="v19-chain" style="color:#7B2E2E">Where later readers differ: ' + esc(s.caution) + '</div>';
    }
    h += '</div>' +
         '<p class="v19-offline-note" style="margin-top:12px">The 1917 Scofield Reference Bible is in the public domain. ' +
         'The note above is a summary of Scofield\'s position written for this app, not a transcription of his wording. ' +
         'It is kept separate from this app\'s own commentary on purpose.</p></div>';

    h += '<div data-pane-body="app" hidden style="margin-top:14px">' +
         '<span class="v19-badge plain">Study Hub commentary</span>' +
         '<p>Close this panel to return to the page\'s own commentary on ' + esc(rec.ref) + '. ' +
         'The two are deliberately not merged — Scofield is a historical witness here, not the house view.</p></div>';

    var bodyEl = V19.openSheet("Scofield layer — " + rec.ref, h);

    bodyEl.querySelectorAll(".v19-tab").forEach(function (t) {
      t.addEventListener("click", function () {
        bodyEl.querySelectorAll(".v19-tab").forEach(function (x) { x.setAttribute("aria-selected", "false"); });
        t.setAttribute("aria-selected", "true");
        bodyEl.querySelectorAll("[data-pane-body]").forEach(function (p) {
          p.hidden = p.getAttribute("data-pane-body") !== t.dataset.pane;
        });
      });
    });
  };

  /* Inline mount, for pages that want Scofield beside the commentary
     rather than in a modal:  <div data-scofield-slot></div>          */
  function mountInlineScofield() {
    var slot = document.querySelector("[data-scofield-slot]");
    var rec = primary();
    if (!slot || !rec || !rec.scofield) return;
    var s = rec.scofield;
    slot.innerHTML =
      '<div class="v19-scofield">' +
        '<span class="v19-badge">1917 Scofield Reference — summarised</span>' +
        '<p>' + esc(s.note) + '</p>' +
        (s.chain ? '<div class="v19-chain">Chain reference: ' + s.chain.map(esc).join(" · ") + '</div>' : '') +
        (s.caution ? '<div class="v19-chain" style="color:#7B2E2E">Where later readers differ: ' + esc(s.caution) + '</div>' : '') +
      '</div>';
  }

  /* ==========================================================
     BOOT
     ========================================================== */
  function start() {
    buildTicker();
    buildRail();
    mountInlineScofield();
    V19.enableZoom(document);   /* catch anything the modules added */
  }

  if (document.body && document.body.classList.contains("v19")) start();
  else document.addEventListener("v19:ready", start);
})();
