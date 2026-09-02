#!/usr/bin/env node
/* ============================================================
   LIVING WATERS — BOOK PAGE GENERATOR
   ------------------------------------------------------------
   Emits a complete panorama.html for any book, straight from the
   chapter records already sitting in data/panorama-data.js.

   Usage:
     node build/build-book-page.js genesis
     node build/build-book-page.js genesis --dry     (print, don't write)
     node build/build-book-page.js --all             (every book with data)

   Replaces hand-writing chapter sections. Genesis's 50 sections were
   written by hand; that does not scale to 1,189 chapters.

   Everything it produces is derived from real data:
     - shape-view cell sizes come from actual verse counts, not a
       hardcoded array
     - only chapters that actually exist in the data are marked built
     - period tags come from build/books.js
   ============================================================ */

const fs = require('fs');
const path = require('path');
const { BOOKS, PERIODS, bookBySlug, periodFor } = require('./books.js');

const ROOT = path.join(__dirname, '..');

// ---- load the scripture data (plain browser script → fake a window) ----
function loadChapters() {
  const sandbox = { window: {} };
  const code = fs.readFileSync(path.join(ROOT, 'data', 'panorama-data.js'), 'utf8');
  new Function('window', code)(sandbox.window);
  return sandbox.window.LW_CHAPTERS || {};
}

const esc = s => String(s).replace(/&(?![a-zA-Z]+;|#\d+;)/g, '&amp;');

// ---------------------------------------------------------------
function buildPage(book, CH) {
  // gather the chapters that actually have data
  const chapters = [];
  for (let n = 1; n <= book.chapters; n++) {
    const rec = CH[`${book.slug}-${n}`];
    if (rec) chapters.push({ n, rec });
  }
  if (!chapters.length) return null;

  const builtNums   = chapters.map(c => c.n);
  const isComplete  = builtNums.length === book.chapters;
  const verseCounts = [];
  for (let n = 1; n <= book.chapters; n++) {
    const rec = CH[`${book.slug}-${n}`];
    verseCounts.push(rec ? rec.verses.length : 0);
  }

  // ---- intro chip + blurb reflect real completion state ----
  const chip = isComplete
    ? `<div class="lw-stat-chip lw-stat-chip-amber mb-3"><i class="fa-solid fa-check"></i> Complete — All ${book.chapters} Chapters</div>`
    : `<div class="lw-stat-chip lw-stat-chip-amber mb-3"><i class="fa-solid fa-feather"></i> In Progress — ${builtNums.length} of ${book.chapters} Chapters</div>`;

  const blurb = isComplete
    ? `Every chapter of ${esc(book.name)} is here in full panorama, KJV text throughout. Tap any cell below to jump straight to it.`
    : `Blue/gold cells are built in full panorama; dashed cells aren't written yet. Tap any built cell to jump straight to it.`;

  // ---- chapter sections ----
  const sections = chapters.map(({ n, rec }, i) => {
    const pid = periodFor(book, n);
    const p   = PERIODS[pid];
    const pad = i === 0 ? '22px' : '10px';
    const tag = `<a href="../../periods/${pid}.html" class="fl-period-tag fl-period-${pid}" style="text-decoration:none;"><i class="fa-solid fa-earth-americas"></i> ${p.label} &middot; ${p.span}</a>`;
    const title = rec.title ? ` <span class="text-sm font-normal text-stone-400">&middot; ${esc(rec.title)}</span>` : '';
    return `  <section id="ch${n}" class="fl-reading" style="padding-top:${pad};">
    ${tag}
    <h2 class="lw-serif text-xl font-bold text-stone-900 mb-3">Chapter ${n}${title}</h2>

    <div data-lw-chapter="${book.slug}-${n}"></div>
  </section>`;
  }).join('\n\n');

  // ---- unbuilt-chapter note ----
  const missing = [];
  for (let n = 1; n <= book.chapters; n++) if (!CH[`${book.slug}-${n}`]) missing.push(n);
  const note = missing.length
    ? `\n<div class="max-w-4xl mx-auto px-6">\n  <p class="text-xs text-stone-400 mb-3">${missing.length} chapter${missing.length > 1 ? 's' : ''} not written yet — those cells above are dashed placeholders, not broken links.</p>\n</div>\n`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${esc(book.name)} — Panorama | Living Waters</title>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;600;700&family=Cinzel:wght@600;800;900&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../../../lib/living-waters.css">
</head>
<body class="lw fl-white-page">

<div id="lw-backdrop" class="lw-backdrop"></div>
<div id="lw-photo-credit" class="lw-photo-credit"></div>

<!-- HEADER -->
<header class="w-full bg-slate-950/85 border-b border-sky-500/20 backdrop-blur-md sticky top-0 z-50">
  <div class="bg-amber-500/10 border-b border-amber-500/10 text-amber-300 text-xs py-1 overflow-hidden">
    <div id="lw-top-ticker" class="lw-marquee-track whitespace-nowrap flex items-center font-semibold tracking-wider"></div>
  </div>
  <div class="max-w-4xl mx-auto px-6 py-3 flex items-center justify-between gap-3">
    <a href="../../../index.html" class="flex items-center gap-2.5 no-underline">
      <div class="w-9 h-9 rounded-xl bg-gradient-to-tr from-sky-800 via-slate-600 to-amber-500 flex items-center justify-center border border-sky-300/30">
        <i class="fa-solid fa-droplet text-white text-sm"></i>
      </div>
      <span class="lw-serif font-black text-base tracking-widest text-slate-100">LIVING WATERS</span>
    </a>
    <a href="index.html" class="text-xs text-sky-300/90 hover:text-amber-300 no-underline font-semibold tracking-wide">&larr; ${esc(book.name)}</a>
  </div>
</header>

<!-- INTRO -->
<div class="max-w-4xl mx-auto px-6 pt-8 pb-2 text-center">
  ${chip}
  <h1 class="lw-serif text-2xl md:text-3xl font-black text-stone-900 mb-1">${esc(book.name)}, at a Glance</h1>
  <p class="text-stone-500 text-sm max-w-2xl mx-auto">${blurb}</p>
</div>

<!-- SHAPE VIEW (zoom-out map of the whole book) -->
<div class="fl-shape-wrap">
  <div class="fl-shape-grid" id="fl-shape-grid"></div>
  <div class="fl-shape-legend" style="color:#78716c;">
    <span><i style="background:linear-gradient(135deg,#38bdf8,#f59e0b)"></i>Full panorama</span>
    <span><i style="background:rgba(148,163,184,0.08);border:1px dashed rgba(148,163,184,0.3)"></i>Not yet built</span>
  </div>
</div>

<!-- TOOLBAR: zoom + legend -->
<div class="fl-toolbar">
  <div class="fl-zoom-group">
    <span class="text-xs text-stone-400 mr-1 hidden sm:inline">Text size</span>
    <button class="fl-zoom-btn" id="fl-zoom-out" aria-label="Zoom out">&minus;</button>
    <span class="fl-zoom-label" id="fl-zoom-label">100%</span>
    <button class="fl-zoom-btn" id="fl-zoom-in" aria-label="Zoom in">+</button>
  </div>
  <div class="fl-legend">
    <span class="fl-legend-chip"><span class="fl-legend-dot" style="background:#b45309"></span>God</span>
    <span class="fl-legend-chip"><span class="fl-legend-dot" style="background:#0e7490"></span>Time</span>
    <span class="fl-legend-chip"><span class="fl-legend-dot" style="background:#1d4ed8"></span>People</span>
    <span class="fl-legend-chip"><span class="fl-legend-dot" style="background:#15803d"></span>Place</span>
  </div>
</div>

<!-- PERSISTENT MINI TABLE OF CONTENTS -->
<nav class="fl-mini-toc" id="fl-mini-toc" aria-label="Chapter quick-jump">
  <span class="fl-mini-toc-label">${esc(book.name)}</span>
</nav>

<!-- CONTINUOUS READING AREA -->
<main class="fl-passage" id="fl-passage">

${sections}

</main>
${note}
<script src="../../../lib/living-waters.js"></script>
<script src="../../../data/panorama-data.js"></script>
<script src="../../../lib/panorama-render.js"></script>
<script>
  // Verse counts per chapter, derived from the real data at build time.
  // A 0 means that chapter isn't written yet.
  var verseCounts = [${verseCounts.join(',')}];
  var bookName = ${JSON.stringify(book.name)};
  var built = {};
  [${builtNums.join(',')}].forEach(function(n){ built[n] = 'panorama'; });

  var grid = document.getElementById('fl-shape-grid');
  verseCounts.forEach(function(count, idx){
    var chNum = idx + 1;
    var status = built[chNum];
    var cell = document.createElement(status ? 'a' : 'div');
    cell.className = 'fl-shape-cell ' + (status ? 'fl-shape-panorama' : 'fl-shape-empty');
    cell.style.flexGrow = Math.max(count, 10);
    cell.textContent = chNum;
    cell.title = bookName + ' ' + chNum + (status ? '' : ' — not yet built');
    if (status) { cell.href = '#ch' + chNum; }
    grid.appendChild(cell);
  });

  // Persistent mini-TOC — built chapters only
  var miniToc = document.getElementById('fl-mini-toc');
  var miniChips = [];
  Object.keys(built).forEach(function(chNum){
    var chip = document.createElement('a');
    chip.className = 'fl-mini-toc-chip';
    chip.href = '#ch' + chNum;
    chip.textContent = chNum;
    chip.style.background = 'linear-gradient(135deg,#38bdf8,#f59e0b)';
    chip.style.color = '#0c1220';
    chip.dataset.ch = chNum;
    miniToc.appendChild(chip);
    miniChips.push(chip);
  });

  // Scroll-spy: highlight whichever chapter section is in view
  var sections = Object.keys(built).map(function(n){ return document.getElementById('ch' + n); }).filter(Boolean);
  function updateCurrent(){
    var pos = window.scrollY + 120;
    var current = sections[0];
    sections.forEach(function(sec){ if (sec.offsetTop <= pos) current = sec; });
    miniChips.forEach(function(chip){
      chip.classList.toggle('fl-mini-current', current && chip.dataset.ch === current.id.replace('ch',''));
    });
  }
  window.addEventListener('scroll', updateCurrent, { passive: true });
  updateCurrent();

  // Zoom controls
  (function(){
    var scale = 1;
    var min = 0.75, max = 1.6, step = 0.1;
    var label = document.getElementById('fl-zoom-label');
    var passage = document.getElementById('fl-passage');
    function apply(){
      passage.style.setProperty('--fl-scale', scale.toFixed(2));
      label.textContent = Math.round(scale * 100) + '%';
    }
    document.getElementById('fl-zoom-in').addEventListener('click', function(){
      scale = Math.min(max, +(scale + step).toFixed(2)); apply();
    });
    document.getElementById('fl-zoom-out').addEventListener('click', function(){
      scale = Math.max(min, +(scale - step).toFixed(2)); apply();
    });
    apply();
  })();
</script>

</body>
</html>
`;
}

// ---------------------------------------------------------------
function main() {
  const args = process.argv.slice(2);
  const dry  = args.includes('--dry');
  const CH   = loadChapters();

  let targets;
  if (args.includes('--all')) {
    targets = BOOKS.filter(b => CH[`${b.slug}-1`]);
  } else {
    const slugs = args.filter(a => !a.startsWith('--'));
    if (!slugs.length) {
      console.error('Usage: node build/build-book-page.js <book-slug> [--dry]  |  --all');
      process.exit(1);
    }
    targets = slugs.map(s => {
      const b = bookBySlug(s);
      if (!b) { console.error(`Unknown book slug: ${s}`); process.exit(1); }
      return b;
    });
  }

  if (!targets.length) { console.log('No books have chapter data yet.'); return; }

  targets.forEach(book => {
    const html = buildPage(book, CH);
    if (!html) { console.log(`SKIP  ${book.name} — no chapter data`); return; }

    const dir  = path.join(ROOT, 'scripture-studies', book.testament, book.slug);
    const dest = path.join(dir, 'panorama.html');

    if (dry) {
      console.log(`DRY   ${book.name} → ${html.length} bytes (not written)`);
      return;
    }
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(dest, html);

    let n = 0; for (let c = 1; c <= book.chapters; c++) if (CH[`${book.slug}-${c}`]) n++;
    console.log(`WROTE ${book.name.padEnd(16)} ${String(n).padStart(3)}/${String(book.chapters).padEnd(3)} chapters → ${path.relative(ROOT, dest)}`);
  });
}

if (require.main === module) main();
module.exports = { buildPage, loadChapters };
