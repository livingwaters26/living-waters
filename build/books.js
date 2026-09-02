/* ============================================================
   LIVING WATERS — CANONICAL BOOK REGISTRY
   ------------------------------------------------------------
   One row per book of the 66-book Protestant canon.

     name      display name
     slug      folder name under scripture-studies/<testament>/
     testament 'old-testament' | 'new-testament'
     chapters  chapter count  — HARD validation (very reliable)
     verses    KJV verse total — SOFT validation (warn only; a few
               books have long-standing variant counts, e.g. 3 John)
     periods   chapter-range → period id, for the coloured period tag.
               Ranges must cover 1..chapters with no gaps.

   Period ids must match the .fl-period-* classes already defined in
   lib/living-waters.css. All 12 exist there already.
   ============================================================ */

// label + genesis-style range caption shown inside the period tag
const PERIODS = {
  'early-world':      { label: 'Early World',        span: 'Genesis 1&ndash;11' },
  'patriarchs':       { label: 'Patriarchs',         span: 'Genesis 12&ndash;50' },
  'egypt-exodus':     { label: 'Egypt &amp; Exodus', span: 'Exodus 1&ndash;18' },
  'desert':           { label: 'Desert Wanderings',  span: 'Exodus 19 &ndash; Deuteronomy' },
  'conquest-judges':  { label: 'Conquest &amp; Judges', span: 'Joshua &ndash; Ruth' },
  'royal-kingdom':    { label: 'Royal Kingdom',      span: 'United Israel' },
  'divided-kingdom':  { label: 'Divided Kingdom',    span: 'Israel &amp; Judah' },
  'exile':            { label: 'Exile',              span: 'Babylon' },
  'return':           { label: 'Return',             span: 'Rebuilding Jerusalem' },
  'maccabean':        { label: 'Maccabean Revolt',   span: 'Between the Testaments' },
  'messianic':        { label: 'Messianic Fulfillment', span: 'The Gospels' },
  'church':           { label: 'The Church',         span: 'Acts &ndash; Revelation' }
};

// helper: whole book sits in one period
const all = (id) => [{ from: 1, to: Infinity, period: id }];

const BOOKS = [
  // ---------- OLD TESTAMENT ----------
  { name:'Genesis',        slug:'genesis',        chapters:50,  verses:1533, periods:[{from:1,to:11,period:'early-world'},{from:12,to:50,period:'patriarchs'}] },
  { name:'Exodus',         slug:'exodus',         chapters:40,  verses:1213, periods:[{from:1,to:18,period:'egypt-exodus'},{from:19,to:40,period:'desert'}] },
  { name:'Leviticus',      slug:'leviticus',      chapters:27,  verses:859,  periods:all('desert') },
  { name:'Numbers',        slug:'numbers',        chapters:36,  verses:1288, periods:all('desert') },
  { name:'Deuteronomy',    slug:'deuteronomy',    chapters:34,  verses:959,  periods:all('desert') },
  { name:'Joshua',         slug:'joshua',         chapters:24,  verses:658,  periods:all('conquest-judges') },
  { name:'Judges',         slug:'judges',         chapters:21,  verses:618,  periods:all('conquest-judges') },
  { name:'Ruth',           slug:'ruth',           chapters:4,   verses:85,   periods:all('conquest-judges') },
  { name:'1 Samuel',       slug:'1-samuel',       chapters:31,  verses:810,  periods:all('royal-kingdom') },
  { name:'2 Samuel',       slug:'2-samuel',       chapters:24,  verses:695,  periods:all('royal-kingdom') },
  { name:'1 Kings',        slug:'1-kings',        chapters:22,  verses:816,  periods:[{from:1,to:11,period:'royal-kingdom'},{from:12,to:22,period:'divided-kingdom'}] },
  { name:'2 Kings',        slug:'2-kings',        chapters:25,  verses:719,  periods:all('divided-kingdom') },
  { name:'1 Chronicles',   slug:'1-chronicles',   chapters:29,  verses:942,  periods:all('royal-kingdom') },
  { name:'2 Chronicles',   slug:'2-chronicles',   chapters:36,  verses:822,  periods:[{from:1,to:9,period:'royal-kingdom'},{from:10,to:36,period:'divided-kingdom'}] },
  { name:'Ezra',           slug:'ezra',           chapters:10,  verses:280,  periods:all('return') },
  { name:'Nehemiah',       slug:'nehemiah',       chapters:13,  verses:406,  periods:all('return') },
  { name:'Esther',         slug:'esther',         chapters:10,  verses:167,  periods:all('return') },
  { name:'Job',            slug:'job',            chapters:42,  verses:1070, periods:all('patriarchs') },
  { name:'Psalms',         slug:'psalms',         chapters:150, verses:2461, periods:all('royal-kingdom') },
  { name:'Proverbs',       slug:'proverbs',       chapters:31,  verses:915,  periods:all('royal-kingdom') },
  { name:'Ecclesiastes',   slug:'ecclesiastes',   chapters:12,  verses:222,  periods:all('royal-kingdom') },
  { name:'Song of Solomon',slug:'song-of-solomon',chapters:8,   verses:117,  periods:all('royal-kingdom') },
  { name:'Isaiah',         slug:'isaiah',         chapters:66,  verses:1292, periods:all('divided-kingdom') },
  { name:'Jeremiah',       slug:'jeremiah',       chapters:52,  verses:1364, periods:all('divided-kingdom') },
  { name:'Lamentations',   slug:'lamentations',   chapters:5,   verses:154,  periods:all('exile') },
  { name:'Ezekiel',        slug:'ezekiel',        chapters:48,  verses:1273, periods:all('exile') },
  { name:'Daniel',         slug:'daniel',         chapters:12,  verses:357,  periods:all('exile') },
  { name:'Hosea',          slug:'hosea',          chapters:14,  verses:197,  periods:all('divided-kingdom') },
  { name:'Joel',           slug:'joel',           chapters:3,   verses:73,   periods:all('divided-kingdom') },
  { name:'Amos',           slug:'amos',           chapters:9,   verses:146,  periods:all('divided-kingdom') },
  { name:'Obadiah',        slug:'obadiah',        chapters:1,   verses:21,   periods:all('divided-kingdom') },
  { name:'Jonah',          slug:'jonah',          chapters:4,   verses:48,   periods:all('divided-kingdom') },
  { name:'Micah',          slug:'micah',          chapters:7,   verses:105,  periods:all('divided-kingdom') },
  { name:'Nahum',          slug:'nahum',          chapters:3,   verses:47,   periods:all('divided-kingdom') },
  { name:'Habakkuk',       slug:'habakkuk',       chapters:3,   verses:56,   periods:all('divided-kingdom') },
  { name:'Zephaniah',      slug:'zephaniah',      chapters:3,   verses:53,   periods:all('divided-kingdom') },
  { name:'Haggai',         slug:'haggai',         chapters:2,   verses:38,   periods:all('return') },
  { name:'Zechariah',      slug:'zechariah',      chapters:14,  verses:211,  periods:all('return') },
  { name:'Malachi',        slug:'malachi',        chapters:4,   verses:55,   periods:all('return') },

  // ---------- NEW TESTAMENT ----------
  { name:'Matthew',        slug:'matthew',        chapters:28,  verses:1071, periods:all('messianic') },
  { name:'Mark',           slug:'mark',           chapters:16,  verses:678,  periods:all('messianic') },
  { name:'Luke',           slug:'luke',           chapters:24,  verses:1151, periods:all('messianic') },
  { name:'John',           slug:'john',           chapters:21,  verses:879,  periods:all('messianic') },
  { name:'Acts',           slug:'acts',           chapters:28,  verses:1007, periods:all('church') },
  { name:'Romans',         slug:'romans',         chapters:16,  verses:433,  periods:all('church') },
  { name:'1 Corinthians',  slug:'1-corinthians',  chapters:16,  verses:437,  periods:all('church') },
  { name:'2 Corinthians',  slug:'2-corinthians',  chapters:13,  verses:257,  periods:all('church') },
  { name:'Galatians',      slug:'galatians',      chapters:6,   verses:149,  periods:all('church') },
  { name:'Ephesians',      slug:'ephesians',      chapters:6,   verses:155,  periods:all('church') },
  { name:'Philippians',    slug:'philippians',    chapters:4,   verses:104,  periods:all('church') },
  { name:'Colossians',     slug:'colossians',     chapters:4,   verses:95,   periods:all('church') },
  { name:'1 Thessalonians',slug:'1-thessalonians',chapters:5,   verses:89,   periods:all('church') },
  { name:'2 Thessalonians',slug:'2-thessalonians',chapters:3,   verses:47,   periods:all('church') },
  { name:'1 Timothy',      slug:'1-timothy',      chapters:6,   verses:113,  periods:all('church') },
  { name:'2 Timothy',      slug:'2-timothy',      chapters:4,   verses:83,   periods:all('church') },
  { name:'Titus',          slug:'titus',          chapters:3,   verses:46,   periods:all('church') },
  { name:'Philemon',       slug:'philemon',       chapters:1,   verses:25,   periods:all('church') },
  { name:'Hebrews',        slug:'hebrews',        chapters:13,  verses:303,  periods:all('church') },
  { name:'James',          slug:'james',          chapters:5,   verses:108,  periods:all('church') },
  { name:'1 Peter',        slug:'1-peter',        chapters:5,   verses:105,  periods:all('church') },
  { name:'2 Peter',        slug:'2-peter',        chapters:3,   verses:61,   periods:all('church') },
  { name:'1 John',         slug:'1-john',         chapters:5,   verses:105,  periods:all('church') },
  { name:'2 John',         slug:'2-john',         chapters:1,   verses:13,   periods:all('church') },
  { name:'3 John',         slug:'3-john',         chapters:1,   verses:14,   periods:all('church') },
  { name:'Jude',           slug:'jude',           chapters:1,   verses:25,   periods:all('church') },
  { name:'Revelation',     slug:'revelation',     chapters:22,  verses:404,  periods:all('church') }
];

// first 39 are OT, remainder NT
BOOKS.forEach((b, i) => { b.testament = i < 39 ? 'old-testament' : 'new-testament'; });

function bookBySlug(slug) { return BOOKS.find(b => b.slug === slug); }
function bookByName(name) {
  const norm = s => s.toLowerCase().replace(/[^a-z0-9]/g, '');
  return BOOKS.find(b => norm(b.name) === norm(name));
}
// which period a given chapter number falls in
function periodFor(book, chapter) {
  const r = book.periods.find(r => chapter >= r.from && chapter <= r.to);
  return r ? r.period : null;
}

module.exports = { BOOKS, PERIODS, bookBySlug, bookByName, periodFor };
