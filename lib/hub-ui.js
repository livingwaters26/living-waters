/* ============================================================
   Study Hub v19 — core interface layer
   Load AFTER data/passage-data.js. No dependencies.

   Does three things:
     1. Strips build/progress metadata out of headings
     2. Adds a persistent reading-size control
     3. Makes content boxes open in a focused full-screen sheet

   Everything degrades quietly: if a page has none of the
   expected structures, nothing happens and nothing breaks.
   ============================================================ */
(function () {
  "use strict";

  var V19 = window.V19 = window.V19 || {};

  /* ---- storage helper (localStorage may be blocked) -------- */
  V19.store = {
    get: function (k, d) {
      try { var v = localStorage.getItem(k); return v === null ? d : v; }
      catch (e) { return d; }
    },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };

  /* ==========================================================
     1. METADATA STRIPPER
     Removes developer-facing progress text from headings so a
     header carries only its title and scripture reference.
     Works on text, not on your markup, so it runs on every page
     without your having to edit any of them.
     ========================================================== */

  var META_PATTERNS = [
    /\(?\s*\d+\s*(?:of|\/)\s*\d+\s*(?:chapters?|books?|sections?|pages?)?\s*(?:built|done|complete[d]?|finished)\s*\)?/gi,
    /\(?\s*\d+\s*(?:of|\/)\s*\d+\s*(?:chapters?|books?|sections?)\s*\)?/gi,
    /\[?\s*(?:TODO|WIP|FIXME|DRAFT|STUB|PLACEHOLDER)\s*[:\-]?\s*[^\]\n]{0,40}\]?/gi,
    /\bv\d+(?:\.\d+)*\s*(?:build|rev|snapshot)\b/gi,
    /\b(?:build|rev(?:ision)?)\s*#?\s*\d+\b/gi,
    /\bstatus\s*[:\-]\s*(?:in\s+progress|queued|stub|pending|not\s+started)\b/gi,
    /\b\d+\s*%\s*(?:complete|done|built)\b/gi
  ];

  /* Elements whose entire job is to show build status. */
  var META_SELECTORS = [
    ".build-status", ".build-meta", ".progress-meta", ".progress-badge",
    ".dev-note", ".status-badge", ".chapter-count", ".completion",
    "[data-build-status]", "[data-progress]"
  ].join(",");

  function cleanString(s) {
    var out = s;
    META_PATTERNS.forEach(function (re) { out = out.replace(re, " "); });
    /* tidy the punctuation the removal leaves behind */
    return out
      .replace(/\s*[|·—–-]\s*(?=$|[|·—–-])/g, " ")
      .replace(/\(\s*\)|\[\s*\]/g, " ")
      .replace(/\s*[|·]\s*$/, "")
      .replace(/\s{2,}/g, " ")
      .trim();
  }

  V19.stripMetadata = function (root) {
    root = root || document;
    var removed = 0;

    /* whole elements first */
    root.querySelectorAll(META_SELECTORS).forEach(function (el) {
      el.remove(); removed++;
    });

    /* then text inside headings and their immediate label children */
    root.querySelectorAll("h1,h2,h3,h4,h5,.section-title,.card-title,.box-title")
      .forEach(function (h) {
        walkText(h, function (node) {
          var cleaned = cleanString(node.nodeValue);
          if (cleaned !== node.nodeValue.trim()) { node.nodeValue = cleaned ? cleaned + " " : ""; removed++; }
        });
        /* drop child spans emptied by the pass above */
        Array.prototype.slice.call(h.children).forEach(function (c) {
          if (!c.textContent.trim() && !c.querySelector("img,svg")) c.remove();
        });
      });

    return removed;
  };

  function walkText(el, fn) {
    var w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    var nodes = [], n;
    while ((n = w.nextNode())) nodes.push(n);
    nodes.forEach(fn);
  }

  /* ==========================================================
     2. READING SIZE
     Four steps, remembered per device. Rendered into the ticker
     tool group if the ticker is present, otherwise floated.
     ========================================================== */

  V19.typeScale = {
    step: parseInt(V19.store.get("v19.type", "1"), 10) || 1,
    apply: function () {
      var h = document.documentElement;
      h.className = h.className.replace(/\bv19-type-\d\b/g, "").trim();
      h.classList.add("v19-type-" + this.step);
      V19.store.set("v19.type", String(this.step));
    },
    nudge: function (d) {
      this.step = Math.max(0, Math.min(3, this.step + d));
      this.apply();
    }
  };

  /* ==========================================================
     3. FOCUS SHEET (click-to-zoom)
     A shared full-screen overlay used by the zoom feature and
     by the compare / Scofield modules.
     ========================================================== */

  var overlay, sheetBody, sheetLabel, lastFocus;

  function buildOverlay() {
    if (overlay) return;
    overlay = document.createElement("div");
    overlay.className = "v19-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.hidden = false;
    overlay.innerHTML =
      '<div class="v19-sheet">' +
        '<div class="v19-sheet-bar">' +
          '<span class="v19-sheet-label"></span>' +
          '<button class="v19-btn v19-btn-close" type="button">Close</button>' +
        '</div>' +
        '<div class="v19-sheet-body"></div>' +
      '</div>';
    document.body.appendChild(overlay);
    sheetBody = overlay.querySelector(".v19-sheet-body");
    sheetLabel = overlay.querySelector(".v19-sheet-label");

    overlay.querySelector(".v19-btn-close").addEventListener("click", V19.closeSheet);
    overlay.addEventListener("click", function (e) {
      if (e.target === overlay) V19.closeSheet();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && overlay.classList.contains("open")) V19.closeSheet();
    });
  }

  V19.openSheet = function (label, htmlOrNode) {
    buildOverlay();
    lastFocus = document.activeElement;
    sheetLabel.textContent = label || "";
    sheetBody.innerHTML = "";
    if (typeof htmlOrNode === "string") sheetBody.innerHTML = htmlOrNode;
    else sheetBody.appendChild(htmlOrNode);
    overlay.classList.add("open");
    document.body.style.overflow = "hidden";
    overlay.querySelector(".v19-btn-close").focus();
    document.dispatchEvent(new CustomEvent("v19:sheetopen", { detail: { body: sheetBody } }));
    return sheetBody;
  };

  V19.closeSheet = function () {
    if (!overlay) return;
    overlay.classList.remove("open");
    document.body.style.overflow = "";
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  };

  /* ---- wiring zoom onto content boxes ---------------------- */

  var ZOOM_SELECTORS = [
    ".card", ".box", ".section-box", ".detail-card", ".compare-box",
    ".passage-card", ".view-box", ".commentary-card", ".panel",
    "[data-zoom]"
  ].join(",");

  /* Never zoom something that is really a control or a container
     of other zoomable boxes. */
  function isZoomable(el) {
    if (el.closest(".v19-overlay,.v19-rail,.v19-ticker")) return false;
    if (el.querySelector(ZOOM_SELECTORS)) return false;      /* it's a grid, not a card */
    if (el.matches("a,button,nav,form")) return false;
    if (el.textContent.trim().length < 24) return false;
    return true;
  }

  V19.enableZoom = function (root) {
    root = root || document;
    var count = 0;
    root.querySelectorAll(ZOOM_SELECTORS).forEach(function (el) {
      if (el.dataset.v19Zoom || !isZoomable(el)) return;
      el.dataset.v19Zoom = "1";
      el.classList.add("v19-zoomable");
      el.setAttribute("tabindex", "0");
      el.setAttribute("role", "button");

      var tag = document.createElement("span");
      tag.className = "v19-zoom-tag";
      tag.textContent = "OPEN ⤢";
      el.appendChild(tag);
      count++;

      /* Drag / text-selection guard. The app's select-to-highlight
         and select-to-note tools must keep working, so a click that
         moved the pointer or left a selection behind is not a zoom. */
      var sx = 0, sy = 0;
      el.addEventListener("pointerdown", function (e) { sx = e.clientX; sy = e.clientY; });

      el.addEventListener("click", function (e) {
        if (e.target.closest("a,button,input,select,textarea,label,.v19-card-save")) return;
        if (Math.abs(e.clientX - sx) > 6 || Math.abs(e.clientY - sy) > 6) return;
        var sel = window.getSelection();
        if (sel && String(sel).trim().length) return;
        openZoom(el);
      });

      el.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); openZoom(el); }
      });
    });
    return count;
  };

  function openZoom(el) {
    var clone = el.cloneNode(true);
    clone.classList.remove("v19-zoomable");
    clone.removeAttribute("tabindex");
    clone.removeAttribute("role");
    clone.removeAttribute("data-v19-zoom");
    var t = clone.querySelector(".v19-zoom-tag"); if (t) t.remove();

    var heading = el.querySelector("h1,h2,h3,h4,.card-title,.box-title,strong");
    var label = heading ? heading.textContent.trim().slice(0, 60) : "Focused view";
    V19.openSheet(label, clone);
  }

  /* ==========================================================
     BOOT
     ========================================================== */

  function boot() {
    document.body.classList.add("v19");
    V19.typeScale.apply();
    V19.stripMetadata(document);
    V19.enableZoom(document);
    document.dispatchEvent(new CustomEvent("v19:ready"));
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
