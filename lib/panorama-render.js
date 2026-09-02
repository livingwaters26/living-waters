/* ============================================================
   Living Waters — panorama renderer
   Turns plain verse text from data/panorama-data.js into the
   white-mode reading HTML: verse numbers + auto word-coloring.
   Add a new chapter by adding data, not by hand-writing spans.
   ============================================================ */

(function () {
  // Keyword rules, checked longest-phrase-first so multi-word
  // matches (e.g. "LORD God") win over single-word ones ("God").
  var RULES = [
    { cat: 'god',    words: ['LORD God', 'Spirit of God', 'sons of God', 'angel of the LORD', 'God', 'LORD', 'Lord'] },
    { cat: 'people', words: ['Abraham', 'Abram', 'Sarah', 'Sarai', 'Isaac', 'Jacob', 'Israel', 'Joseph', 'Reuben', 'Judah', 'Pharaoh', 'Lot', 'Adam', 'Eve', 'Noah', 'Shem, Ham, and Japheth', 'Shem', 'Ham', 'Japheth', 'Ishmeelites', 'Midianites', 'woman', 'man'] },
    { cat: 'time',   words: ['evening and the morning', 'seventh day', 'third day', 'hundred and twenty years', 'seventy and five years old', 'seventeen years old', 'first day', 'second day', 'fourth day', 'fifth day', 'sixth day', 'day', 'days', 'years', 'night'] },
    { cat: 'place',  words: ['garden of Eden', 'garden', 'Heaven', 'heaven', 'Earth', 'Seas', 'Canaan', 'Haran', 'Egypt', 'Sodom', 'Gomorrah', 'Bethel', 'Moriah', 'Shechem', 'Dothan', 'Beersheba', 'Mamre'] }
  ];

  function escapeHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // Wrap keyword matches in coloring spans without double-wrapping
  // text already inside a span (walks the string, skips matched ranges).
  function colorize(text) {
    var text_escaped = escapeHtml(text);
    var matches = []; // {start, end, cat}
    RULES.forEach(function (rule) {
      rule.words.forEach(function (w) {
        var re = new RegExp('\\b' + w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b', 'g');
        var m;
        while ((m = re.exec(text_escaped))) {
          var s = m.index, e = m.index + m[0].length;
          var overlaps = matches.some(function (x) { return s < x.end && e > x.start; });
          if (!overlaps) matches.push({ start: s, end: e, cat: rule.cat });
        }
      });
    });
    matches.sort(function (a, b) { return a.start - b.start; });
    var out = '', pos = 0;
    matches.forEach(function (m) {
      out += text_escaped.slice(pos, m.start);
      out += '<span class="fl-w-' + m.cat + '">' + text_escaped.slice(m.start, m.end) + '</span>';
      pos = m.end;
    });
    out += text_escaped.slice(pos);
    return out;
  }

  // Groups verses into paragraphs of ~5 verses each (simple readable chunking).
  function renderChapter(key, translation) {
    var data = window.LW_CHAPTERS && window.LW_CHAPTERS[key];
    if (!data) return '<p class="text-red-600">Chapter data not found: ' + key + '</p>';
    translation = translation || 'KJV';
    var html = '';
    var chunk = [];
    data.verses.forEach(function (v, i) {
      var text = v.t[translation] || v.t.KJV;
      chunk.push('<span class="fl-vnum">' + v.n + '</span>' + colorize(text));
      var isLast = i === data.verses.length - 1;
      if (chunk.length >= 5 || isLast) {
        html += '<p>' + chunk.join(' ') + '</p>\n';
        chunk = [];
      }
    });
    return html;
  }

  window.LW_renderChapter = renderChapter;

  // Auto-render any element with data-lw-chapter="genesis-1"
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-lw-chapter]').forEach(function (el) {
      var key = el.getAttribute('data-lw-chapter');
      var translation = el.getAttribute('data-lw-translation') || 'KJV';
      el.innerHTML = renderChapter(key, translation);
    });
  });
})();
