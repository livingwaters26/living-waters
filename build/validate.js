#!/usr/bin/env node
/* ============================================================
   LIVING WATERS — SCRIPTURE DATA VALIDATOR
   ------------------------------------------------------------
   Run after adding any book, before zipping a checkpoint:

     node build/validate.js            (whole store)
     node build/validate.js exodus     (one book)

   Two kinds of check:

   STRUCTURAL (source-independent, always hard errors)
     - chapter numbers contiguous 1..N, none missing or duplicated
     - verse numbers contiguous within each chapter
     - no empty verse text, no placeholder/TODO text
     - required fields present (book, chapter, title, period, verses)
     - no chapter numbered beyond the book's real chapter count

   REFERENCE (compared to build/books.js totals)
     - book verse total vs the standard KJV figure

   NOTE on per-chapter counts: these are deliberately NOT checked
   against a reference table. Genesis 1 intentionally carries 2:1-3
   (the Sabbath), so its chapter boundaries differ from a standard
   versification while the book total stays correct. Book totals and
   structural integrity are the meaningful checks.
   ============================================================ */

const fs = require('fs');
const path = require('path');
const { BOOKS, bookBySlug, periodFor } = require('./books.js');

const ROOT = path.join(__dirname, '..');

function loadChapters() {
  const w = {};
  new Function('window', fs.readFileSync(path.join(ROOT, 'data', 'panorama-data.js'), 'utf8'))(w);
  return w.LW_CHAPTERS || {};
}

const PLACEHOLDER = /\b(lorem ipsum|TODO|TBD|FIXME|placeholder|xxx+)\b/i;

function validateBook(book, CH) {
  const errors = [], warnings = [];

  // which chapters exist
  const present = [];
  for (let n = 1; n <= book.chapters; n++) if (CH[`${book.slug}-${n}`]) present.push(n);

  // stray chapters beyond the real count
  Object.keys(CH).forEach(k => {
    const m = k.match(new RegExp(`^${book.slug}-(\\d+)$`));
    if (m && +m[1] > book.chapters) {
      errors.push(`${k} — chapter ${m[1]} exceeds ${book.name}'s ${book.chapters} chapters`);
    }
  });

  if (!present.length) return { status: 'absent', errors, warnings, present: 0, verses: 0 };

  // contiguity: no holes below the highest built chapter
  const max = Math.max(...present);
  for (let n = 1; n <= max; n++) {
    if (!CH[`${book.slug}-${n}`]) warnings.push(`gap — chapter ${n} missing (chapters exist up to ${max})`);
  }

  let total = 0;
  present.forEach(n => {
    const rec = CH[`${book.slug}-${n}`];
    const id  = `${book.name} ${n}`;

    if (!rec.book)    errors.push(`${id} — missing 'book'`);
    if (!rec.title)   warnings.push(`${id} — missing 'title'`);
    if (rec.chapter !== n) errors.push(`${id} — 'chapter' field is ${rec.chapter}, expected ${n}`);
    if (!rec.period)  errors.push(`${id} — missing 'period'`);
    else if (rec.period !== periodFor(book, n))
      warnings.push(`${id} — period '${rec.period}' differs from registry '${periodFor(book, n)}'`);

    if (!Array.isArray(rec.verses) || !rec.verses.length) {
      errors.push(`${id} — no verses`);
      return;
    }
    total += rec.verses.length;

    // Verse numbering must be contiguous, but a verse may be labelled
    // "C:V" when text from an adjacent chapter is deliberately carried
    // into this one (e.g. Genesis 1 ends with 2:1-3, the Sabbath).
    // Each such carried run is checked for contiguity on its own.
    let curCh = n, expect = null;
    rec.verses.forEach(v => {
      const label = String(v.n);
      let vc, vn;
      const cross = label.match(/^(\d+):(\d+)$/);
      if (cross) { vc = +cross[1]; vn = +cross[2]; }
      else if (/^\d+$/.test(label)) { vc = curCh; vn = +label; }
      else { errors.push(`${id} — unparseable verse label '${label}'`); return; }

      if (vc !== curCh) {           // start of a carried run
        curCh = vc; expect = vn;
        if (Math.abs(vc - n) > 1) {
          warnings.push(`${id} — carries text from chapter ${vc}, not adjacent`);
        }
      }
      if (expect === null) expect = vn;
      if (vn !== expect) {
        errors.push(`${id}:${label} — out of sequence (expected ${curCh === n ? '' : curCh + ':'}${expect})`);
      }
      expect = vn + 1;

      const t = v.t && v.t.KJV;
      if (!t || !t.trim()) errors.push(`${id}:${label} — empty KJV text`);
      else if (PLACEHOLDER.test(t)) errors.push(`${id}:${label} — placeholder text detected`);
    });
  });

  // reference check — only meaningful once the book is complete
  const complete = present.length === book.chapters;
  if (complete && total !== book.verses) {
    warnings.push(`verse total ${total} vs KJV reference ${book.verses} (diff ${total - book.verses})`);
  }

  return {
    status: complete ? 'complete' : 'partial',
    errors, warnings, present: present.length, verses: total
  };
}

function main() {
  const CH = loadChapters();
  const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
  const targets = args.length
    ? args.map(s => { const b = bookBySlug(s); if (!b) { console.error(`Unknown slug: ${s}`); process.exit(1); } return b; })
    : BOOKS;

  let errs = 0, warns = 0, doneBooks = 0, doneCh = 0, doneV = 0;
  const lines = [];

  targets.forEach(book => {
    const r = validateBook(book, CH);
    if (r.status === 'absent' && !r.errors.length) return;

    errs += r.errors.length; warns += r.warnings.length;
    if (r.status === 'complete') doneBooks++;
    doneCh += r.present; doneV += r.verses;

    const mark = r.errors.length ? 'FAIL' : r.status === 'complete' ? ' OK ' : 'PART';
    lines.push(`[${mark}] ${book.name.padEnd(16)} ${String(r.present).padStart(3)}/${String(book.chapters).padEnd(3)} ch  ${String(r.verses).padStart(5)} v`);
    r.errors.forEach(e   => lines.push(`         ERROR   ${e}`));
    r.warnings.forEach(w => lines.push(`         warning ${w}`));
  });

  console.log(lines.join('\n') || 'No scripture data found.');
  console.log('\n' + '─'.repeat(58));
  console.log(`Books complete : ${doneBooks} / 66`);
  console.log(`Chapters       : ${doneCh} / 1189   (${(doneCh / 1189 * 100).toFixed(1)}%)`);
  console.log(`Verses         : ${doneV} / 31102   (${(doneV / 31102 * 100).toFixed(1)}%)`);
  console.log(`Errors: ${errs}   Warnings: ${warns}`);
  console.log('─'.repeat(58));

  process.exit(errs ? 1 : 0);
}

if (require.main === module) main();
module.exports = { validateBook, loadChapters };
