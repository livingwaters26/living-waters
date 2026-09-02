/// Curated ~30–45 minute "drive drama" episode map for the whole Bible.
///
/// When the user picks a book, [episodesForBook] returns only that book's
/// segments. Titles are drive-friendly; ranges are natural story arcs
/// (not arbitrary chapter cuts). Duration labels are estimates for a
/// full-cast dramatized reading with light connective tissue and SFX.

class BibleEpisode {
  /// Stable id, e.g. "john-05".
  final String id;

  /// Must match [BibleTextService.bookOrder] names exactly.
  final String book;

  /// Short title for the list, e.g. "Blind man & the good shepherd".
  final String title;

  final int startChapter;
  final int endChapter;

  /// Rough dramatized length, e.g. "30–40 min".
  final String approxDuration;

  const BibleEpisode({
    required this.id,
    required this.book,
    required this.title,
    required this.startChapter,
    required this.endChapter,
    required this.approxDuration,
  });

  String get rangeLabel {
    if (startChapter == endChapter) return 'Chapter $startChapter';
    return 'Chapters $startChapter–$endChapter';
  }
}

/// All curated episodes. Grouped by book for maintenance; use
/// [episodesForBook] / [booksWithEpisodes] at runtime.
const List<BibleEpisode> kBibleEpisodes = [
  // ——— Genesis ———
  BibleEpisode(id: 'gen-01', book: 'Genesis', title: 'Creation & the fall', startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-02', book: 'Genesis', title: 'Cain to the flood', startChapter: 4, endChapter: 8, approxDuration: '35–45 min'),
  BibleEpisode(id: 'gen-03', book: 'Genesis', title: 'Noah to Babel & Abram called', startChapter: 9, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-04', book: 'Genesis', title: "Abraham's journeys & covenant", startChapter: 13, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-05', book: 'Genesis', title: 'Sodom to Isaac born', startChapter: 18, endChapter: 21, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-06', book: 'Genesis', title: 'Isaac offered; finds a wife', startChapter: 22, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-07', book: 'Genesis', title: 'Jacob & Esau', startChapter: 25, endChapter: 28, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-08', book: 'Genesis', title: 'Jacob in Haran', startChapter: 29, endChapter: 31, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-09', book: 'Genesis', title: 'Return, Dinah, Bethel', startChapter: 32, endChapter: 35, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-10', book: 'Genesis', title: 'Joseph sold to Egypt', startChapter: 37, endChapter: 41, approxDuration: '35–45 min'),
  BibleEpisode(id: 'gen-11', book: 'Genesis', title: 'Brothers to Egypt', startChapter: 42, endChapter: 45, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gen-12', book: 'Genesis', title: 'Jacob in Egypt to the end', startChapter: 46, endChapter: 50, approxDuration: '30–40 min'),

  // ——— Exodus ———
  BibleEpisode(id: 'exo-01', book: 'Exodus', title: 'Oppression & Moses called', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-02', book: 'Exodus', title: 'Confronting Pharaoh', startChapter: 5, endChapter: 11, approxDuration: '35–45 min'),
  BibleEpisode(id: 'exo-03', book: 'Exodus', title: 'Passover & the Red Sea', startChapter: 12, endChapter: 15, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-04', book: 'Exodus', title: 'Wilderness to Sinai', startChapter: 16, endChapter: 19, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-05', book: 'Exodus', title: 'Commandments & covenant', startChapter: 20, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-06', book: 'Exodus', title: 'Tabernacle instructions', startChapter: 25, endChapter: 31, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-07', book: 'Exodus', title: 'Golden calf & renewed covenant', startChapter: 32, endChapter: 34, approxDuration: '30–40 min'),
  BibleEpisode(id: 'exo-08', book: 'Exodus', title: 'Tabernacle built', startChapter: 35, endChapter: 40, approxDuration: '30–40 min'),

  // ——— Leviticus ———
  BibleEpisode(id: 'lev-01', book: 'Leviticus', title: 'The offerings', startChapter: 1, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'lev-02', book: 'Leviticus', title: 'Priests & dedication', startChapter: 8, endChapter: 10, approxDuration: '25–35 min'),
  BibleEpisode(id: 'lev-03', book: 'Leviticus', title: 'Clean and unclean', startChapter: 11, endChapter: 15, approxDuration: '30–40 min'),
  BibleEpisode(id: 'lev-04', book: 'Leviticus', title: 'Atonement & holiness', startChapter: 16, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: 'lev-05', book: 'Leviticus', title: 'Priests, feasts, vows', startChapter: 21, endChapter: 27, approxDuration: '30–40 min'),

  // ——— Numbers ———
  BibleEpisode(id: 'num-01', book: 'Numbers', title: 'Census & the camp', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'num-02', book: 'Numbers', title: 'Laws & Passover', startChapter: 5, endChapter: 9, approxDuration: '30–40 min'),
  BibleEpisode(id: 'num-03', book: 'Numbers', title: 'Leave Sinai; complaints', startChapter: 10, endChapter: 14, approxDuration: '35–45 min'),
  BibleEpisode(id: 'num-04', book: 'Numbers', title: 'Rebellion & wanderings', startChapter: 15, endChapter: 20, approxDuration: '35–45 min'),
  BibleEpisode(id: 'num-05', book: 'Numbers', title: 'Bronze serpent to Balaam', startChapter: 21, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: 'num-06', book: 'Numbers', title: 'Peor to succession', startChapter: 25, endChapter: 30, approxDuration: '30–40 min'),
  BibleEpisode(id: 'num-07', book: 'Numbers', title: 'Allotment & cities', startChapter: 31, endChapter: 36, approxDuration: '30–40 min'),

  // ——— Deuteronomy ———
  BibleEpisode(id: 'deu-01', book: 'Deuteronomy', title: 'Moses reviews the journey', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'deu-02', book: 'Deuteronomy', title: 'Law restated', startChapter: 5, endChapter: 11, approxDuration: '35–45 min'),
  BibleEpisode(id: 'deu-03', book: 'Deuteronomy', title: 'Detailed statutes', startChapter: 12, endChapter: 16, approxDuration: '30–40 min'),
  BibleEpisode(id: 'deu-04', book: 'Deuteronomy', title: 'Leaders, war, justice', startChapter: 17, endChapter: 21, approxDuration: '30–40 min'),
  BibleEpisode(id: 'deu-05', book: 'Deuteronomy', title: 'Community laws', startChapter: 22, endChapter: 26, approxDuration: '30–40 min'),
  BibleEpisode(id: 'deu-06', book: 'Deuteronomy', title: 'Covenant, song, death of Moses', startChapter: 27, endChapter: 34, approxDuration: '35–45 min'),

  // ——— Joshua ———
  BibleEpisode(id: 'jos-01', book: 'Joshua', title: 'Entering the land', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jos-02', book: 'Joshua', title: 'Jericho to Ai', startChapter: 6, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jos-03', book: 'Joshua', title: 'Southern & northern campaigns', startChapter: 9, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jos-04', book: 'Joshua', title: 'Allotment of the land', startChapter: 13, endChapter: 19, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jos-05', book: 'Joshua', title: 'Refuge cities to covenant', startChapter: 20, endChapter: 24, approxDuration: '30–40 min'),

  // ——— Judges ———
  BibleEpisode(id: 'jdg-01', book: 'Judges', title: 'Failure after Joshua', startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jdg-02', book: 'Judges', title: 'Deborah & Gideon begins', startChapter: 4, endChapter: 7, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jdg-03', book: 'Judges', title: 'Gideon to Abimelech', startChapter: 8, endChapter: 9, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jdg-04', book: 'Judges', title: 'Jephthah', startChapter: 10, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jdg-05', book: 'Judges', title: 'Samson', startChapter: 13, endChapter: 16, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jdg-06', book: 'Judges', title: 'Idolatry & civil war', startChapter: 17, endChapter: 21, approxDuration: '30–40 min'),

  // ——— Ruth ———
  BibleEpisode(id: 'rut-01', book: 'Ruth', title: 'Ruth (whole book)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),

  // ——— 1 Samuel ———
  BibleEpisode(id: '1sa-01', book: '1 Samuel', title: "Samuel's birth & call", startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-02', book: '1 Samuel', title: "Ark & Eli's house", startChapter: 4, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-03', book: '1 Samuel', title: 'Israel wants a king', startChapter: 8, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-04', book: '1 Samuel', title: "Saul's early reign", startChapter: 13, endChapter: 15, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-05', book: '1 Samuel', title: 'David anointed; Goliath', startChapter: 16, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-06', book: '1 Samuel', title: 'David & Saul', startChapter: 18, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-07', book: '1 Samuel', title: 'David the fugitive', startChapter: 21, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: '1sa-08', book: '1 Samuel', title: "Nabal to Saul's end", startChapter: 25, endChapter: 31, approxDuration: '35–45 min'),

  // ——— 2 Samuel ———
  BibleEpisode(id: '2sa-01', book: '2 Samuel', title: 'David becomes king', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: '2sa-02', book: '2 Samuel', title: 'Ark & covenant', startChapter: 6, endChapter: 7, approxDuration: '25–35 min'),
  BibleEpisode(id: '2sa-03', book: '2 Samuel', title: 'Wars & kindness', startChapter: 8, endChapter: 10, approxDuration: '25–35 min'),
  BibleEpisode(id: '2sa-04', book: '2 Samuel', title: 'Bathsheba & fallout', startChapter: 11, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: '2sa-05', book: '2 Samuel', title: 'Amnon & Absalom', startChapter: 13, endChapter: 15, approxDuration: '30–40 min'),
  BibleEpisode(id: '2sa-06', book: '2 Samuel', title: "Absalom's revolt", startChapter: 16, endChapter: 19, approxDuration: '35–45 min'),
  BibleEpisode(id: '2sa-07', book: '2 Samuel', title: 'Final crises & song', startChapter: 20, endChapter: 24, approxDuration: '30–40 min'),

  // ——— 1 Kings ———
  BibleEpisode(id: '1ki-01', book: '1 Kings', title: 'Solomon established', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ki-02', book: '1 Kings', title: 'Temple built', startChapter: 5, endChapter: 8, approxDuration: '35–45 min'),
  BibleEpisode(id: '1ki-03', book: '1 Kings', title: "Solomon's peak & decline", startChapter: 9, endChapter: 11, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ki-04', book: '1 Kings', title: 'Kingdom divided', startChapter: 12, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ki-05', book: '1 Kings', title: 'Kings & Elijah begins', startChapter: 15, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ki-06', book: '1 Kings', title: 'Elijah vs Baal; flight', startChapter: 18, endChapter: 19, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ki-07', book: '1 Kings', title: "Ahab's wars & death", startChapter: 20, endChapter: 22, approxDuration: '30–40 min'),

  // ——— 2 Kings ———
  BibleEpisode(id: '2ki-01', book: '2 Kings', title: 'Elijah to Elisha', startChapter: 1, endChapter: 2, approxDuration: '25–35 min'),
  BibleEpisode(id: '2ki-02', book: '2 Kings', title: "Elisha's ministry", startChapter: 3, endChapter: 8, approxDuration: '35–45 min'),
  BibleEpisode(id: '2ki-03', book: '2 Kings', title: 'Jehu', startChapter: 9, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ki-04', book: '2 Kings', title: 'Joash to fall of Israel', startChapter: 11, endChapter: 17, approxDuration: '35–45 min'),
  BibleEpisode(id: '2ki-05', book: '2 Kings', title: 'Hezekiah', startChapter: 18, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ki-06', book: '2 Kings', title: 'Manasseh to exile', startChapter: 21, endChapter: 25, approxDuration: '30–40 min'),

  // ——— 1 Chronicles ———
  BibleEpisode(id: '1ch-01', book: '1 Chronicles', title: 'Genealogies (overview)', startChapter: 1, endChapter: 9, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ch-02', book: '1 Chronicles', title: "Saul's end; David's rise", startChapter: 10, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ch-03', book: '1 Chronicles', title: 'Ark & covenant', startChapter: 13, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ch-04', book: '1 Chronicles', title: 'Wars & temple prep', startChapter: 18, endChapter: 22, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ch-05', book: '1 Chronicles', title: 'Levites & worship', startChapter: 23, endChapter: 27, approxDuration: '30–40 min'),
  BibleEpisode(id: '1ch-06', book: '1 Chronicles', title: "Temple charge; David's end", startChapter: 28, endChapter: 29, approxDuration: '25–35 min'),

  // ——— 2 Chronicles ———
  BibleEpisode(id: '2ch-01', book: '2 Chronicles', title: 'Solomon', startChapter: 1, endChapter: 9, approxDuration: '35–45 min'),
  BibleEpisode(id: '2ch-02', book: '2 Chronicles', title: 'Rehoboam to Asa', startChapter: 10, endChapter: 16, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ch-03', book: '2 Chronicles', title: 'Jehoshaphat', startChapter: 17, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ch-04', book: '2 Chronicles', title: 'Joash to Ahaz', startChapter: 21, endChapter: 28, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ch-05', book: '2 Chronicles', title: 'Hezekiah', startChapter: 29, endChapter: 32, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ch-06', book: '2 Chronicles', title: 'Manasseh to exile', startChapter: 33, endChapter: 36, approxDuration: '30–40 min'),

  // ——— Ezra / Nehemiah / Esther ———
  BibleEpisode(id: 'ezr-01', book: 'Ezra', title: 'Return & foundation', startChapter: 1, endChapter: 3, approxDuration: '25–35 min'),
  BibleEpisode(id: 'ezr-02', book: 'Ezra', title: 'Opposition & completion', startChapter: 4, endChapter: 6, approxDuration: '25–35 min'),
  BibleEpisode(id: 'ezr-03', book: 'Ezra', title: "Ezra's return & reform", startChapter: 7, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'neh-01', book: 'Nehemiah', title: 'Wall rebuilt', startChapter: 1, endChapter: 7, approxDuration: '35–45 min'),
  BibleEpisode(id: 'neh-02', book: 'Nehemiah', title: 'Law read; covenant', startChapter: 8, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'neh-03', book: 'Nehemiah', title: 'Dedication & reforms', startChapter: 11, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'est-01', book: 'Esther', title: 'Risk & the decree', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: 'est-02', book: 'Esther', title: 'Reversal & Purim', startChapter: 6, endChapter: 10, approxDuration: '30–40 min'),

  // ——— Job ———
  BibleEpisode(id: 'job-01', book: 'Job', title: 'Prologue & lament', startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: 'job-02', book: 'Job', title: 'First cycle of speeches', startChapter: 4, endChapter: 14, approxDuration: '35–45 min'),
  BibleEpisode(id: 'job-03', book: 'Job', title: 'Second cycle', startChapter: 15, endChapter: 21, approxDuration: '30–40 min'),
  BibleEpisode(id: 'job-04', book: 'Job', title: 'Third cycle', startChapter: 22, endChapter: 27, approxDuration: '30–40 min'),
  BibleEpisode(id: 'job-05', book: 'Job', title: "Wisdom & Job's oath", startChapter: 28, endChapter: 31, approxDuration: '30–40 min'),
  BibleEpisode(id: 'job-06', book: 'Job', title: 'Elihu', startChapter: 32, endChapter: 37, approxDuration: '30–40 min'),
  BibleEpisode(id: 'job-07', book: 'Job', title: 'The Lord speaks; epilogue', startChapter: 38, endChapter: 42, approxDuration: '30–40 min'),

  // ——— Psalms ———
  BibleEpisode(id: 'psa-01', book: 'Psalms', title: 'Psalms 1–8', startChapter: 1, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-02', book: 'Psalms', title: 'Psalms 9–18', startChapter: 9, endChapter: 18, approxDuration: '35–45 min'),
  BibleEpisode(id: 'psa-03', book: 'Psalms', title: 'Psalms 19–25', startChapter: 19, endChapter: 25, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-04', book: 'Psalms', title: 'Psalms 26–34', startChapter: 26, endChapter: 34, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-05', book: 'Psalms', title: 'Psalms 35–41', startChapter: 35, endChapter: 41, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-06', book: 'Psalms', title: 'Psalms 42–49', startChapter: 42, endChapter: 49, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-07', book: 'Psalms', title: 'Psalms 50–56', startChapter: 50, endChapter: 56, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-08', book: 'Psalms', title: 'Psalms 57–67', startChapter: 57, endChapter: 67, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-09', book: 'Psalms', title: 'Psalms 68–72', startChapter: 68, endChapter: 72, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-10', book: 'Psalms', title: 'Psalms 73–78', startChapter: 73, endChapter: 78, approxDuration: '35–45 min'),
  BibleEpisode(id: 'psa-11', book: 'Psalms', title: 'Psalms 79–89', startChapter: 79, endChapter: 89, approxDuration: '35–45 min'),
  BibleEpisode(id: 'psa-12', book: 'Psalms', title: 'Psalms 90–97', startChapter: 90, endChapter: 97, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-13', book: 'Psalms', title: 'Psalms 98–106', startChapter: 98, endChapter: 106, approxDuration: '35–45 min'),
  BibleEpisode(id: 'psa-14', book: 'Psalms', title: 'Psalms 107–112', startChapter: 107, endChapter: 112, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-15', book: 'Psalms', title: 'Psalms 113–118', startChapter: 113, endChapter: 118, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-16', book: 'Psalms', title: 'Psalm 119 (part 1)', startChapter: 119, endChapter: 119, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-17', book: 'Psalms', title: 'Songs of Ascents (120–134)', startChapter: 120, endChapter: 134, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-18', book: 'Psalms', title: 'Psalms 135–145', startChapter: 135, endChapter: 145, approxDuration: '30–40 min'),
  BibleEpisode(id: 'psa-19', book: 'Psalms', title: 'Psalms 146–150', startChapter: 146, endChapter: 150, approxDuration: '25–35 min'),

  // ——— Proverbs / Ecclesiastes / Song ———
  BibleEpisode(id: 'pro-01', book: 'Proverbs', title: 'Proverbs 1–4', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'pro-02', book: 'Proverbs', title: 'Proverbs 5–9', startChapter: 5, endChapter: 9, approxDuration: '30–40 min'),
  BibleEpisode(id: 'pro-03', book: 'Proverbs', title: 'Proverbs 10–15', startChapter: 10, endChapter: 15, approxDuration: '35–45 min'),
  BibleEpisode(id: 'pro-04', book: 'Proverbs', title: 'Proverbs 16–21', startChapter: 16, endChapter: 21, approxDuration: '35–45 min'),
  BibleEpisode(id: 'pro-05', book: 'Proverbs', title: 'Proverbs 22–24', startChapter: 22, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: 'pro-06', book: 'Proverbs', title: 'Proverbs 25–29', startChapter: 25, endChapter: 29, approxDuration: '30–40 min'),
  BibleEpisode(id: 'pro-07', book: 'Proverbs', title: 'Proverbs 30–31', startChapter: 30, endChapter: 31, approxDuration: '25–35 min'),
  BibleEpisode(id: 'ecc-01', book: 'Ecclesiastes', title: 'Ecclesiastes 1–6', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ecc-02', book: 'Ecclesiastes', title: 'Ecclesiastes 7–12', startChapter: 7, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'sng-01', book: 'Song of Solomon', title: 'Song of Songs (whole)', startChapter: 1, endChapter: 8, approxDuration: '30–40 min'),

  // ——— Isaiah ———
  BibleEpisode(id: 'isa-01', book: 'Isaiah', title: 'Isaiah 1–6', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: 'isa-02', book: 'Isaiah', title: 'Isaiah 7–12', startChapter: 7, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'isa-03', book: 'Isaiah', title: 'Isaiah 13–23', startChapter: 13, endChapter: 23, approxDuration: '35–45 min'),
  BibleEpisode(id: 'isa-04', book: 'Isaiah', title: 'Isaiah 24–27', startChapter: 24, endChapter: 27, approxDuration: '30–40 min'),
  BibleEpisode(id: 'isa-05', book: 'Isaiah', title: 'Isaiah 28–35', startChapter: 28, endChapter: 35, approxDuration: '35–45 min'),
  BibleEpisode(id: 'isa-06', book: 'Isaiah', title: 'Isaiah 36–39', startChapter: 36, endChapter: 39, approxDuration: '30–40 min'),
  BibleEpisode(id: 'isa-07', book: 'Isaiah', title: 'Isaiah 40–48', startChapter: 40, endChapter: 48, approxDuration: '35–45 min'),
  BibleEpisode(id: 'isa-08', book: 'Isaiah', title: 'Isaiah 49–55', startChapter: 49, endChapter: 55, approxDuration: '30–40 min'),
  BibleEpisode(id: 'isa-09', book: 'Isaiah', title: 'Isaiah 56–66', startChapter: 56, endChapter: 66, approxDuration: '35–45 min'),

  // ——— Jeremiah / Lamentations ———
  BibleEpisode(id: 'jer-01', book: 'Jeremiah', title: 'Jeremiah 1–6', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-02', book: 'Jeremiah', title: 'Jeremiah 7–10', startChapter: 7, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-03', book: 'Jeremiah', title: 'Jeremiah 11–15', startChapter: 11, endChapter: 15, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-04', book: 'Jeremiah', title: 'Jeremiah 16–20', startChapter: 16, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-05', book: 'Jeremiah', title: 'Jeremiah 21–25', startChapter: 21, endChapter: 25, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-06', book: 'Jeremiah', title: 'Jeremiah 26–29', startChapter: 26, endChapter: 29, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-07', book: 'Jeremiah', title: 'Jeremiah 30–33', startChapter: 30, endChapter: 33, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-08', book: 'Jeremiah', title: 'Jeremiah 34–38', startChapter: 34, endChapter: 38, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-09', book: 'Jeremiah', title: 'Jeremiah 39–45', startChapter: 39, endChapter: 45, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jer-10', book: 'Jeremiah', title: 'Jeremiah 46–52', startChapter: 46, endChapter: 52, approxDuration: '35–45 min'),
  BibleEpisode(id: 'lam-01', book: 'Lamentations', title: 'Lamentations (whole)', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),

  // ——— Ezekiel / Daniel ———
  BibleEpisode(id: 'ezk-01', book: 'Ezekiel', title: 'Ezekiel 1–7', startChapter: 1, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-02', book: 'Ezekiel', title: 'Ezekiel 8–11', startChapter: 8, endChapter: 11, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-03', book: 'Ezekiel', title: 'Ezekiel 12–17', startChapter: 12, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-04', book: 'Ezekiel', title: 'Ezekiel 18–24', startChapter: 18, endChapter: 24, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-05', book: 'Ezekiel', title: 'Ezekiel 25–32', startChapter: 25, endChapter: 32, approxDuration: '35–45 min'),
  BibleEpisode(id: 'ezk-06', book: 'Ezekiel', title: 'Ezekiel 33–36', startChapter: 33, endChapter: 36, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-07', book: 'Ezekiel', title: 'Ezekiel 37–39', startChapter: 37, endChapter: 39, approxDuration: '30–40 min'),
  BibleEpisode(id: 'ezk-08', book: 'Ezekiel', title: 'Ezekiel 40–48', startChapter: 40, endChapter: 48, approxDuration: '35–45 min'),
  BibleEpisode(id: 'dan-01', book: 'Daniel', title: 'Court stories (1–6)', startChapter: 1, endChapter: 6, approxDuration: '35–45 min'),
  BibleEpisode(id: 'dan-02', book: 'Daniel', title: 'Visions (7–12)', startChapter: 7, endChapter: 12, approxDuration: '35–45 min'),

  // ——— Minor prophets ———
  BibleEpisode(id: 'hos-01', book: 'Hosea', title: 'Hosea 1–7', startChapter: 1, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'hos-02', book: 'Hosea', title: 'Hosea 8–14', startChapter: 8, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jol-01', book: 'Joel', title: 'Joel (whole)', startChapter: 1, endChapter: 3, approxDuration: '25–35 min'),
  BibleEpisode(id: 'amo-01', book: 'Amos', title: 'Amos (whole)', startChapter: 1, endChapter: 9, approxDuration: '35–45 min'),
  BibleEpisode(id: 'oba-01', book: 'Obadiah', title: 'Obadiah (whole)', startChapter: 1, endChapter: 1, approxDuration: '15–25 min'),
  BibleEpisode(id: 'jon-01', book: 'Jonah', title: 'Jonah (whole)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),
  BibleEpisode(id: 'mic-01', book: 'Micah', title: 'Micah (whole)', startChapter: 1, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'nam-01', book: 'Nahum', title: 'Nahum (whole)', startChapter: 1, endChapter: 3, approxDuration: '20–30 min'),
  BibleEpisode(id: 'hab-01', book: 'Habakkuk', title: 'Habakkuk (whole)', startChapter: 1, endChapter: 3, approxDuration: '20–30 min'),
  BibleEpisode(id: 'zep-01', book: 'Zephaniah', title: 'Zephaniah (whole)', startChapter: 1, endChapter: 3, approxDuration: '20–30 min'),
  BibleEpisode(id: 'hag-01', book: 'Haggai', title: 'Haggai (whole)', startChapter: 1, endChapter: 2, approxDuration: '15–25 min'),
  BibleEpisode(id: 'zec-01', book: 'Zechariah', title: 'Zechariah 1–8', startChapter: 1, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'zec-02', book: 'Zechariah', title: 'Zechariah 9–14', startChapter: 9, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mal-01', book: 'Malachi', title: 'Malachi (whole)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),

  // ——— Matthew ———
  BibleEpisode(id: 'mat-01', book: 'Matthew', title: 'Birth & beginning', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-02', book: 'Matthew', title: 'Sermon on the Mount', startChapter: 5, endChapter: 7, approxDuration: '35–45 min'),
  BibleEpisode(id: 'mat-03', book: 'Matthew', title: 'Healings & mission', startChapter: 8, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-04', book: 'Matthew', title: 'Opposition grows', startChapter: 11, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-05', book: 'Matthew', title: 'Ministry continues', startChapter: 14, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-06', book: 'Matthew', title: 'Community & road to Jerusalem', startChapter: 18, endChapter: 20, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-07', book: 'Matthew', title: 'Temple conflicts', startChapter: 21, endChapter: 23, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-08', book: 'Matthew', title: 'Olivet discourse', startChapter: 24, endChapter: 25, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mat-09', book: 'Matthew', title: 'Passion', startChapter: 26, endChapter: 27, approxDuration: '35–45 min'),
  BibleEpisode(id: 'mat-10', book: 'Matthew', title: 'Resurrection', startChapter: 28, endChapter: 28, approxDuration: '15–25 min'),

  // ——— Mark ———
  BibleEpisode(id: 'mrk-01', book: 'Mark', title: 'Beginning & early ministry', startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mrk-02', book: 'Mark', title: 'Parables & power', startChapter: 4, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mrk-03', book: 'Mark', title: 'Mission & confession', startChapter: 6, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mrk-04', book: 'Mark', title: 'To Jerusalem', startChapter: 9, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mrk-05', book: 'Mark', title: 'Temple & teaching', startChapter: 11, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'mrk-06', book: 'Mark', title: 'Passion & resurrection', startChapter: 14, endChapter: 16, approxDuration: '35–45 min'),

  // ——— Luke ———
  BibleEpisode(id: 'luk-01', book: 'Luke', title: 'Birth narrative', startChapter: 1, endChapter: 2, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-02', book: 'Luke', title: 'Beginning of ministry', startChapter: 3, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-03', book: 'Luke', title: 'Teaching & healings', startChapter: 6, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-04', book: 'Luke', title: 'Mission & journey start', startChapter: 9, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-05', book: 'Luke', title: 'Discipleship on the road', startChapter: 11, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-06', book: 'Luke', title: 'Toward Jerusalem', startChapter: 14, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-07', book: 'Luke', title: 'Jericho to the temple', startChapter: 18, endChapter: 21, approxDuration: '30–40 min'),
  BibleEpisode(id: 'luk-08', book: 'Luke', title: 'Passion', startChapter: 22, endChapter: 23, approxDuration: '35–45 min'),
  BibleEpisode(id: 'luk-09', book: 'Luke', title: 'Resurrection', startChapter: 24, endChapter: 24, approxDuration: '25–35 min'),

  // ——— John ———
  BibleEpisode(id: 'jhn-01', book: 'John', title: 'Prologue & first disciples', startChapter: 1, endChapter: 2, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jhn-02', book: 'John', title: "Nicodemus to the official's son", startChapter: 3, endChapter: 4, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jhn-03', book: 'John', title: 'Bethesda to Bread of Life', startChapter: 5, endChapter: 6, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jhn-04', book: 'John', title: 'Feast conflicts', startChapter: 7, endChapter: 8, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jhn-05', book: 'John', title: 'Blind man & the good shepherd', startChapter: 9, endChapter: 10, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jhn-06', book: 'John', title: 'Lazarus to the plot', startChapter: 11, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jhn-07', book: 'John', title: 'Upper room', startChapter: 13, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jhn-08', book: 'John', title: 'Vine, Spirit, and prayer', startChapter: 15, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jhn-09', book: 'John', title: 'Arrest to burial', startChapter: 18, endChapter: 19, approxDuration: '35–45 min'),
  BibleEpisode(id: 'jhn-10', book: 'John', title: 'Resurrection & the beach', startChapter: 20, endChapter: 21, approxDuration: '30–40 min'),

  // ——— Acts ———
  BibleEpisode(id: 'act-01', book: 'Acts', title: 'Ascension to Pentecost', startChapter: 1, endChapter: 2, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-02', book: 'Acts', title: 'Early church', startChapter: 3, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-03', book: 'Acts', title: 'Stephen to Saul', startChapter: 6, endChapter: 9, approxDuration: '35–45 min'),
  BibleEpisode(id: 'act-04', book: 'Acts', title: 'Peter & the Gentiles', startChapter: 10, endChapter: 12, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-05', book: 'Acts', title: "Paul's first journey", startChapter: 13, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-06', book: 'Acts', title: 'Council & second journey', startChapter: 15, endChapter: 17, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-07', book: 'Acts', title: 'Corinth to Ephesus', startChapter: 18, endChapter: 19, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-08', book: 'Acts', title: 'To Jerusalem', startChapter: 20, endChapter: 21, approxDuration: '30–40 min'),
  BibleEpisode(id: 'act-09', book: 'Acts', title: 'Trials', startChapter: 22, endChapter: 26, approxDuration: '35–45 min'),
  BibleEpisode(id: 'act-10', book: 'Acts', title: 'Voyage to Rome', startChapter: 27, endChapter: 28, approxDuration: '30–40 min'),

  // ——— Paul & general letters ———
  BibleEpisode(id: 'rom-01', book: 'Romans', title: 'Romans 1–4', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rom-02', book: 'Romans', title: 'Romans 5–8', startChapter: 5, endChapter: 8, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rom-03', book: 'Romans', title: 'Romans 9–11', startChapter: 9, endChapter: 11, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rom-04', book: 'Romans', title: 'Romans 12–16', startChapter: 12, endChapter: 16, approxDuration: '30–40 min'),
  BibleEpisode(id: '1co-01', book: '1 Corinthians', title: '1 Corinthians 1–4', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: '1co-02', book: '1 Corinthians', title: '1 Corinthians 5–7', startChapter: 5, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: '1co-03', book: '1 Corinthians', title: '1 Corinthians 8–11', startChapter: 8, endChapter: 11, approxDuration: '30–40 min'),
  BibleEpisode(id: '1co-04', book: '1 Corinthians', title: '1 Corinthians 12–14', startChapter: 12, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: '1co-05', book: '1 Corinthians', title: '1 Corinthians 15–16', startChapter: 15, endChapter: 16, approxDuration: '30–40 min'),
  BibleEpisode(id: '2co-01', book: '2 Corinthians', title: '2 Corinthians 1–5', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: '2co-02', book: '2 Corinthians', title: '2 Corinthians 6–9', startChapter: 6, endChapter: 9, approxDuration: '30–40 min'),
  BibleEpisode(id: '2co-03', book: '2 Corinthians', title: '2 Corinthians 10–13', startChapter: 10, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'gal-01', book: 'Galatians', title: 'Galatians (whole)', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: 'eph-01', book: 'Ephesians', title: 'Ephesians (whole)', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: 'php-01', book: 'Philippians', title: 'Philippians (whole)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),
  BibleEpisode(id: 'col-01', book: 'Colossians', title: 'Colossians (whole)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),
  BibleEpisode(id: '1th-01', book: '1 Thessalonians', title: '1 Thessalonians (whole)', startChapter: 1, endChapter: 5, approxDuration: '25–35 min'),
  BibleEpisode(id: '2th-01', book: '2 Thessalonians', title: '2 Thessalonians (whole)', startChapter: 1, endChapter: 3, approxDuration: '20–30 min'),
  BibleEpisode(id: '1ti-01', book: '1 Timothy', title: '1 Timothy (whole)', startChapter: 1, endChapter: 6, approxDuration: '30–40 min'),
  BibleEpisode(id: '2ti-01', book: '2 Timothy', title: '2 Timothy (whole)', startChapter: 1, endChapter: 4, approxDuration: '25–35 min'),
  BibleEpisode(id: 'tit-01', book: 'Titus', title: 'Titus (whole)', startChapter: 1, endChapter: 3, approxDuration: '20–30 min'),
  BibleEpisode(id: 'phm-01', book: 'Philemon', title: 'Philemon (whole)', startChapter: 1, endChapter: 1, approxDuration: '10–20 min'),
  BibleEpisode(id: 'heb-01', book: 'Hebrews', title: 'Hebrews 1–4', startChapter: 1, endChapter: 4, approxDuration: '30–40 min'),
  BibleEpisode(id: 'heb-02', book: 'Hebrews', title: 'Hebrews 5–7', startChapter: 5, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'heb-03', book: 'Hebrews', title: 'Hebrews 8–10', startChapter: 8, endChapter: 10, approxDuration: '30–40 min'),
  BibleEpisode(id: 'heb-04', book: 'Hebrews', title: 'Hebrews 11–13', startChapter: 11, endChapter: 13, approxDuration: '30–40 min'),
  BibleEpisode(id: 'jas-01', book: 'James', title: 'James (whole)', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: '1pe-01', book: '1 Peter', title: '1 Peter (whole)', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: '2pe-01', book: '2 Peter', title: '2 Peter (whole)', startChapter: 1, endChapter: 3, approxDuration: '25–35 min'),
  BibleEpisode(id: '1jn-01', book: '1 John', title: '1 John (whole)', startChapter: 1, endChapter: 5, approxDuration: '30–40 min'),
  BibleEpisode(id: '2jn-01', book: '2 John', title: '2 John (whole)', startChapter: 1, endChapter: 1, approxDuration: '10–15 min'),
  BibleEpisode(id: '3jn-01', book: '3 John', title: '3 John (whole)', startChapter: 1, endChapter: 1, approxDuration: '10–15 min'),
  BibleEpisode(id: 'jud-01', book: 'Jude', title: 'Jude (whole)', startChapter: 1, endChapter: 1, approxDuration: '15–25 min'),

  // ——— Revelation ———
  BibleEpisode(id: 'rev-01', book: 'Revelation', title: 'Letters to the churches', startChapter: 1, endChapter: 3, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rev-02', book: 'Revelation', title: 'Throne & seals', startChapter: 4, endChapter: 7, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rev-03', book: 'Revelation', title: 'Trumpets', startChapter: 8, endChapter: 11, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rev-04', book: 'Revelation', title: 'Conflict', startChapter: 12, endChapter: 14, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rev-05', book: 'Revelation', title: 'Bowls & Babylon', startChapter: 15, endChapter: 18, approxDuration: '30–40 min'),
  BibleEpisode(id: 'rev-06', book: 'Revelation', title: 'Finale', startChapter: 19, endChapter: 22, approxDuration: '30–40 min'),
];

/// Episodes for one book (empty if unknown).
List<BibleEpisode> episodesForBook(String book) {
  return kBibleEpisodes.where((e) => e.book == book).toList(growable: false);
}

/// Book names that have at least one curated episode, in Bible order when
/// [bookOrder] is provided.
List<String> booksWithEpisodes({List<String>? bookOrder}) {
  final set = kBibleEpisodes.map((e) => e.book).toSet();
  if (bookOrder == null) return set.toList()..sort();
  return bookOrder.where(set.contains).toList(growable: false);
}
