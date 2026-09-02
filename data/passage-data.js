/* ============================================================
   Study Hub v19 — passage dataset
   One record per anchor passage. Every module on the page
   (ticker, insight rail, compare view, Scofield layer) reads
   from here, so a passage is described once and used four ways.

   A page declares which record it wants with:
     <body data-passage="john-1">
   or, for a page covering several, a comma list:
     <body data-passage="gen-1,gen-3">

   TRANSLATION SOURCING
   ASV (1901) and KJV are public domain. Every verse below was
   checked against a published text, not typed from memory.
   NIV and NLT are under active copyright and are NOT reproduced
   here; the compare view links out to them instead.

   SCOFIELD NOTES
   The 1917 Scofield Reference Bible is public domain, but the
   notes below are summaries of Scofield's position written for
   this app, not transcriptions of his exact wording. The UI
   labels them that way.
   ============================================================ */

window.V19_PASSAGES = {

  /* ---------------------------------------------------------- */
  "gen-1": {
    ref: "Genesis 1:1-5",
    title: "Creation — the opening act",
    verses: [1,2,3,4,5],
    translations: {
      ASV: {
        1: "In the beginning God created the heavens and the earth.",
        2: "And the earth was waste and void; and darkness was upon the face of the deep: and the Spirit of God moved upon the face of the waters.",
        3: "And God said, Let there be light: and there was light.",
        4: "And God saw the light, that it was good: and God divided the light from the darkness.",
        5: "And God called the light Day, and the darkness he called Night. And there was evening and there was morning, one day."
      },
      KJV: {
        1: "In the beginning God created the heaven and the earth.",
        2: "And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters.",
        3: "And God said, Let there be light: and there was light.",
        4: "And God saw the light, that it was good: and God divided the light from the darkness.",
        5: "And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day."
      }
    },
    diffNote: "Watch verse 1: ASV reads heavens (plural, following the Hebrew shamayim), KJV reads heaven. Verse 2 splits the same way — waste and void against without form, and void, both rendering tohu wa-bohu.",
    ticker: [
      { src: "fathers", text: "Basil of Caesarea, Hexaemeron (c. 370): the six days are real days, and the account is written to teach worship rather than physics." },
      { src: "fathers", text: "Augustine, De Genesi ad litteram: warned Christians against dogmatism on the mechanics of creation, since a badly argued reading discredits the faith." },
      { src: "catholic", text: "Catechism 337-349: creation is the work of the Trinity, made from nothing, and the sabbath structure of the six days points to worship." },
      { src: "protestant", text: "Calvin, Commentary on Genesis: Moses writes in the language of ordinary sight, describing what any observer would see, not in the language of astronomy." },
      { src: "scofield", text: "Scofield (1917) reads a gap between verses 1 and 2, taking 'was waste and void' as 'became' after a judgment — a minority reading even among dispensationalists today." },
      { src: "crossref", text: "Chain: Gen 1:1 → John 1:1-3 → Col 1:16 → Heb 11:3 → Rev 4:11. The Word who speaks light is the Word who becomes flesh." }
    ],
    consensus: {
      level: "yellow",
      verdict: "Broad agreement that God created freely out of nothing. Sharp disagreement about the age and mechanism of creation — and that split runs inside traditions, not between them.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "yellow", note: "Basil reads six literal days; Origen and Augustine read the days figuratively. No single patristic position." },
        { name: "Catholic",  short: "CAT", level: "green",  note: "Creation ex nihilo is dogma. Humani Generis (1950) leaves the mechanism open to scientific inquiry." },
        { name: "Orthodox",  short: "ORT", level: "green",  note: "Follows the Fathers closely, especially Basil's Hexaemeron. Emphasises creation as gift rather than as a datable event." },
        { name: "Reformers", short: "REF", level: "yellow", note: "Calvin and Luther both assume ordinary days, but Calvin's accommodation principle opened the door to later flexibility." },
        { name: "Mainline",  short: "MLP", level: "yellow", note: "Generally reads Genesis 1 as liturgical poetry making theological claims, not a scientific report." },
        { name: "Evangelical", short: "EVA", level: "red",  note: "The live fault line: young-earth, old-earth, framework, and evolutionary-creation readings all argue from the same text." }
      ]
    },
    scofield: {
      note: "Scofield opens his notes by treating Genesis 1:1 as the absolute beginning, then reads verse 2 as a subsequent ruined state — the 'gap' or restitution theory, in which a divine judgment falls between the two verses and verses 3 onward describe a re-forming of an earth already made. He ties this to Isaiah 45:18 ('he created it not a waste') and to Jeremiah 4:23. He also marks the first dispensation, Innocence, as beginning here and running to the expulsion from Eden.",
      chain: ["Isa 45:18", "Jer 4:23-26", "2 Pet 3:5-7", "John 1:1-3"],
      caution: "The gap reading is now a minority position. Most old-earth and young-earth readers alike take verse 2 as a description of the initial unformed state rather than a ruin."
    },
    cards: [
      { kind: "Cross-reference", text: "John 1:1-3 deliberately echoes this opening. The Gospel's first three words in Greek are the same as the Septuagint's first three words here." },
      { kind: "Historical note", text: "The Enuma Elish and Atrahasis epics describe creation as the by-product of conflict between gods. Genesis 1 has no combat, no rival deity, and no struggle — the sea monsters of verse 21 are simply creatures God makes." },
      { kind: "Study prompt", text: "The text repeats 'and God said' ten times. What does it mean that creation happens by speech rather than by force?" },
      { kind: "Artifact", text: "The Enuma Elish tablets, British Museum", search: "Enuma Elish tablets British Museum" }
    ]
  },

  /* ---------------------------------------------------------- */
  "matt-5": {
    ref: "Matthew 5:3-10",
    title: "The Beatitudes — the shape of the kingdom",
    verses: [3,4,5,6,7,8,9,10],
    translations: {
      ASV: {
        3: "Blessed are the poor in spirit: for theirs is the kingdom of heaven.",
        4: "Blessed are they that mourn: for they shall be comforted.",
        5: "Blessed are the meek: for they shall inherit the earth.",
        6: "Blessed are they that hunger and thirst after righteousness: for they shall be filled.",
        7: "Blessed are the merciful: for they shall obtain mercy.",
        8: "Blessed are the pure in heart: for they shall see God.",
        9: "Blessed are the peacemakers: for they shall be called sons of God.",
        10: "Blessed are they that have been persecuted for righteousness' sake: for theirs is the kingdom of heaven."
      },
      KJV: {
        3: "Blessed are the poor in spirit: for theirs is the kingdom of heaven.",
        4: "Blessed are they that mourn: for they shall be comforted.",
        5: "Blessed are the meek: for they shall inherit the earth.",
        6: "Blessed are they which do hunger and thirst after righteousness: for they shall be filled.",
        7: "Blessed are the merciful: for they shall obtain mercy.",
        8: "Blessed are the pure in heart: for they shall see God.",
        9: "Blessed are the peacemakers: for they shall be called the children of God.",
        10: "Blessed are they which are persecuted for righteousness' sake: for theirs is the kingdom of heaven."
      }
    },
    diffNote: "Verse 9 is the one that matters theologically: ASV has sons of God, KJV has children of God. The Greek is huioi, sons — the ASV keeps the inheritance overtone that 'children' softens. Verse 10's ASV perfect tense (have been persecuted) also points to a settled condition rather than an ongoing one.",
    ticker: [
      { src: "fathers", text: "Chrysostom, Homilies on Matthew 15: poverty of spirit is deliberate humility, the opposite of the pride that made a devil out of an angel." },
      { src: "fathers", text: "Augustine, On the Sermon on the Mount: reads the eight beatitudes as a ladder matched to the seven gifts of the Spirit, ending in peace." },
      { src: "catholic", text: "Catechism 1716-1724: the Beatitudes are the heart of Jesus' preaching and describe the Christian's final vocation, the vision of God." },
      { src: "protestant", text: "Luther distinguishes the two kingdoms here — these are the marks of the Christian before God, not a governing program for the state." },
      { src: "scofield", text: "Scofield (1917) reads the Sermon as primarily the law of the future kingdom, with secondary present application to the church." },
      { src: "crossref", text: "Chain: Matt 5:3 → Isa 61:1-3 → Luke 6:20-26 → Ps 37:11. Jesus is quoting Isaiah's Servant song back to the crowd." }
    ],
    consensus: {
      level: "yellow",
      verdict: "Everyone agrees the Beatitudes describe genuine blessedness. The divide is over when they apply — now, in a future kingdom, or as an impossible standard designed to drive you to grace.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "green",  note: "Read as achievable Christian virtue, aided by grace, and as a ladder of spiritual ascent." },
        { name: "Catholic",  short: "CAT", level: "green",  note: "Binding moral vision for all believers now, fulfilled in the beatific vision." },
        { name: "Orthodox",  short: "ORT", level: "green",  note: "Chanted in the Divine Liturgy at the Little Entrance — treated as the church's own self-description." },
        { name: "Reformers", short: "REF", level: "yellow", note: "Luther and Calvin both affirm present application but stress that the standard exposes sin before it guides conduct." },
        { name: "Mainline",  short: "MLP", level: "green",  note: "Widely read as the charter of Christian social ethics, especially verses 7 and 9." },
        { name: "Evangelical", short: "EVA", level: "red",  note: "Classic dispensationalism postpones the Sermon to the millennial kingdom; progressive dispensationalism and most non-dispensationalists apply it to the church now." }
      ]
    },
    scofield: {
      note: "Scofield treats the Sermon on the Mount as the constitution of the messianic kingdom rather than the rule of life for the church age. On his reading the Sermon is 'legal in character,' addressed to Israel under an offer of the kingdom that was subsequently rejected, and so finds its literal fulfilment in the millennium. He allows a secondary, devotional application to the believer today.",
      chain: ["Isa 61:1-3", "Ps 37:11", "Luke 6:20-26", "Rev 20:4-6"],
      caution: "This postponement reading is the single most contested element of the 1917 notes. Even most later dispensationalists have modified it toward present application."
    },
    cards: [
      { kind: "Cross-reference", text: "Verses 3-4 track Isaiah 61:1-3 almost item for item: good news to the poor, comfort for mourners. Jesus reads that same passage aloud in Luke 4." },
      { kind: "Historical note", text: "Luke's parallel (6:20-26) drops 'in spirit' and adds four woes. The difference has driven the debate over spiritual versus material poverty for eighteen centuries." },
      { kind: "Study prompt", text: "Verses 3 and 10 close with the identical promise. What does that bracket do to the six lines between them?" },
      { kind: "Artifact", text: "Mount of Beatitudes, Galilee", search: "Mount of Beatitudes Galilee traditional site" }
    ]
  },

  /* ---------------------------------------------------------- */
  "john-1": {
    ref: "John 1:1-5",
    title: "The Prologue — the Word before the world",
    verses: [1,2,3,4,5],
    translations: {
      ASV: {
        1: "In the beginning was the Word, and the Word was with God, and the Word was God.",
        2: "The same was in the beginning with God.",
        3: "All things were made through him; and without him was not anything made that hath been made.",
        4: "In him was life; and the life was the light of men.",
        5: "And the light shineth in the darkness; and the darkness apprehended it not."
      },
      KJV: {
        1: "In the beginning was the Word, and the Word was with God, and the Word was God.",
        2: "The same was in the beginning with God.",
        3: "All things were made by him; and without him was not any thing made that was made.",
        4: "In him was life; and the life was the light of men.",
        5: "And the light shineth in darkness; and the darkness comprehended it not."
      }
    },
    diffNote: "Verse 3 is the tell: KJV by him, ASV through him. The Greek preposition is dia, through — agency rather than source, which matters for how the Son relates to the Father in creation. Verse 5: KJV comprehended (did not understand), ASV apprehended (did not overcome). The Greek katelaben carries both, and translators have argued over it since Origen.",
    ticker: [
      { src: "fathers", text: "Athanasius, Against the Arians: if the Word was God, then he is not a creature, and the whole Arian case collapses at verse 1." },
      { src: "fathers", text: "Origen noted the missing article before theos in clause three and read it as qualitative — a distinction later used on both sides of Nicaea." },
      { src: "catholic", text: "Read at the end of every Mass in the Tridentine rite as the Last Gospel — the incarnation restated after every Eucharist." },
      { src: "protestant", text: "Luther called the Prologue the gospel in miniature: everything John will spend twenty-one chapters proving is asserted in five verses." },
      { src: "scofield", text: "Scofield (1917) identifies the Word as the eternal Son, pre-existent and uncreated, and cross-references the Genesis 1 creation account directly." },
      { src: "crossref", text: "Chain: John 1:1 → Gen 1:1 → Prov 8:22-31 → Col 1:15-17 → Heb 1:1-3 → Rev 19:13." }
    ],
    consensus: {
      level: "green",
      verdict: "One of the strongest agreements in the whole canon. Every major tradition reads verse 1 as asserting the full deity and pre-existence of Christ. Divergence is narrow and technical.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "green", note: "The decisive text at Nicaea (325). Athanasius built his case on it." },
        { name: "Catholic",  short: "CAT", level: "green", note: "Foundational to the doctrine of the Trinity and the incarnation." },
        { name: "Orthodox",  short: "ORT", level: "green", note: "Read at the Paschal Liturgy, often in several languages at once." },
        { name: "Reformers", short: "REF", level: "green", note: "Unanimous with the creeds. No Reformation-era dispute on this text." },
        { name: "Mainline",  short: "MLP", level: "green", note: "Affirmed creedally; some scholarship debates Logos background (Hebrew wisdom vs Greek philosophy)." },
        { name: "Evangelical", short: "EVA", level: "green", note: "Central proof text for the deity of Christ. The only live debate is the translation of katelaben in verse 5." }
      ]
    },
    scofield: {
      note: "Scofield identifies the Word as the second person of the Trinity, eternally existent and personally distinct from the Father while sharing the divine nature. He links the Logos directly to the creative speech of Genesis 1 — the 'and God said' of the first chapter is, on his reading, the Word himself acting. He also marks John's Gospel as written to establish belief, citing 20:31 as the stated purpose.",
      chain: ["Gen 1:1-3", "Prov 8:22-31", "Col 1:15-17", "Heb 1:1-3", "Rev 19:13"],
      caution: null
    },
    cards: [
      { kind: "Cross-reference", text: "John's first three Greek words match the Septuagint's first three words in Genesis 1:1 exactly. The echo is deliberate and would have been unmissable to a Greek-reading Jew." },
      { kind: "Historical note", text: "Logos already carried freight in two directions: Stoic philosophy used it for the rational principle ordering the cosmos, and Jewish wisdom literature had personified Wisdom as present at creation. John takes both and says: he is a person, and we knew him." },
      { kind: "Study prompt", text: "Verse 5 shifts to present tense — shineth, not shone. Why does John break his own past-tense sequence exactly there?" },
      { kind: "Artifact", text: "Rylands Papyrus P52, the earliest known New Testament fragment, containing John 18", search: "Rylands Library Papyrus P52 John fragment" }
    ]
  },

  /* ---------------------------------------------------------- */
  "acts-2": {
    ref: "Acts 2:36-38",
    title: "Pentecost — the first sermon and its answer",
    verses: [36,37,38],
    translations: {
      ASV: {
        36: "Let all the house of Israel therefore know assuredly, that God hath made him both Lord and Christ, this Jesus whom ye crucified.",
        37: "Now when they heard this, they were pricked in their heart, and said unto Peter and the rest of the apostles, Brethren, what shall we do?",
        38: "And Peter said unto them, Repent ye, and be baptized every one of you in the name of Jesus Christ unto the remission of your sins; and ye shall receive the gift of the Holy Spirit."
      },
      KJV: {
        36: "Therefore let all the house of Israel know assuredly, that God hath made that same Jesus, whom ye have crucified, both Lord and Christ.",
        37: "Now when they heard this, they were pricked in their heart, and said unto Peter and to the rest of the apostles, Men and brethren, what shall we do?",
        38: "Then Peter said unto them, Repent, and be baptized every one of you in the name of Jesus Christ for the remission of sins, and ye shall receive the gift of the Holy Ghost."
      }
    },
    diffNote: "Verse 38 carries the whole baptismal debate in one preposition: KJV for the remission of sins, ASV unto the remission of your sins. The Greek is eis. Whether it means in order to obtain or with reference to has divided Baptist, Church of Christ, Lutheran, and Catholic readings for centuries — and no English word settles it.",
    ticker: [
      { src: "fathers", text: "Cyril of Jerusalem, Catechetical Lectures: baptism is where forgiveness and the gift of the Spirit are actually received, not merely pictured." },
      { src: "catholic", text: "Catechism 1226-1228: from the day of Pentecost the church has baptized for the forgiveness of sins; this verse is cited directly." },
      { src: "protestant", text: "Most Baptist and Reformed readers take eis as 'with reference to' — baptism testifies to a forgiveness already received by faith." },
      { src: "protestant", text: "Lutheran confessions read baptism as a means of grace here, while still grounding justification in faith alone." },
      { src: "scofield", text: "Scofield (1917) treats Pentecost as the birthday of the church, the moment believers are first baptized by the Spirit into one body." },
      { src: "crossref", text: "Chain: Acts 2:38 → Joel 2:28-32 → Ezek 36:25-27 → Rom 6:3-4 → 1 Cor 12:13 → Titus 3:5." }
    ],
    consensus: {
      level: "red",
      verdict: "The sermon's content is agreed. Verse 38 is not. What baptism does — and whether it is instrumental in forgiveness or declarative of it — is one of the sharpest divides in Christian practice.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "green", note: "Uniformly baptismal-regenerationist in tone: baptism is where remission is conveyed." },
        { name: "Catholic",  short: "CAT", level: "green", note: "Baptism truly remits sin and confers the Spirit. This text is cited in the Catechism as evidence." },
        { name: "Orthodox",  short: "ORT", level: "green", note: "Baptism and chrismation are administered together, matching the two gifts named in the verse." },
        { name: "Reformers", short: "REF", level: "yellow", note: "Luther retains sacramental efficacy; Zwingli reduces baptism to a sign. The split opens here." },
        { name: "Mainline",  short: "MLP", level: "yellow", note: "Sacramental language retained; efficacy described in covenantal rather than causal terms." },
        { name: "Evangelical", short: "EVA", level: "red", note: "Baptist and free-church readings insist baptism follows forgiveness; Churches of Christ read eis as instrumental. Same verse, opposite conclusions." }
      ]
    },
    scofield: {
      note: "Scofield takes Pentecost as the formation of the church as the body of Christ, distinguishing this Spirit baptism from water baptism. On his dispensational scheme Acts 2 marks a genuine transition point: the church age begins here, distinct from Israel's programme, and the promise of verse 39 extends beyond the immediate Jewish audience to those 'afar off.' He treats Peter's use of Joel as illustrative rather than as Joel's final fulfilment, which he places in the still-future day of the Lord.",
      chain: ["Joel 2:28-32", "1 Cor 12:13", "Eph 1:22-23", "Rom 6:3-4"],
      caution: "The claim that Joel is not fulfilled at Pentecost is disputed. Peter's own words are 'this is that which hath been spoken through the prophet Joel.'"
    },
    cards: [
      { kind: "Cross-reference", text: "Peter's charge in verse 36 — 'this Jesus whom ye crucified' — is answered in verse 37 by physical distress. Luke uses the same verb, katanussomai, that the Septuagint uses for Joseph's brothers realising who stands in front of them." },
      { kind: "Historical note", text: "Pentecost (Shavuot) was one of three pilgrimage feasts, so Jerusalem was full of diaspora Jews. That is why the crowd hears in so many languages, and why the church spreads outward so fast afterward." },
      { kind: "Study prompt", text: "Peter's sermon is almost entirely Old Testament quotation. What does it mean that the first Christian sermon is mostly Joel and the Psalms?" },
      { kind: "Artifact", text: "Southern Temple Mount steps and mikva'ot, Jerusalem — plausible site for a mass baptism of three thousand", search: "Southern Steps Temple Mount mikvaot Jerusalem archaeology" }
    ]
  },

  /* ---------------------------------------------------------- */
  "rom-3": {
    ref: "Romans 3:21-26",
    title: "Justification — the hinge of the letter",
    verses: [21,22,23,24,25,26],
    translations: {
      ASV: {
        21: "But now apart from the law a righteousness of God hath been manifested, being witnessed by the law and the prophets;",
        22: "even the righteousness of God through faith in Jesus Christ unto all them that believe; for there is no distinction;",
        23: "for all have sinned, and fall short of the glory of God;",
        24: "being justified freely by his grace through the redemption that is in Christ Jesus:",
        25: "whom God set forth to be a propitiation, through faith, in his blood, to show his righteousness because of the passing over of the sins done aforetime, in the forbearance of God;",
        26: "for the showing, I say, of his righteousness at this present season: that he might himself be just, and the justifier of him that hath faith in Jesus."
      },
      KJV: {
        21: "But now the righteousness of God without the law is manifested, being witnessed by the law and the prophets;",
        22: "Even the righteousness of God which is by faith of Jesus Christ unto all and upon all them that believe: for there is no difference:",
        23: "For all have sinned, and come short of the glory of God;",
        24: "Being justified freely by his grace through the redemption that is in Christ Jesus:",
        25: "Whom God hath set forth to be a propitiation through faith in his blood, to declare his righteousness for the remission of sins that are past, through the forbearance of God;",
        26: "To declare, I say, at this time his righteousness: that he might be just, and the justifier of him which believeth in Jesus."
      }
    },
    diffNote: "Verse 22: KJV faith of Jesus Christ, ASV faith in Jesus Christ. The Greek genitive is ambiguous and the difference is enormous — 'faith in Christ' means our believing; 'faith of Christ' means his own faithfulness. Verse 25: KJV places 'through faith in his blood' as one phrase; ASV separates them with commas, attaching 'in his blood' to the propitiation rather than to faith. Both are defensible readings of the same Greek.",
    ticker: [
      { src: "fathers", text: "Chrysostom, Homilies on Romans 7: righteousness comes as a gift, so that boasting is cut off at the root rather than merely discouraged." },
      { src: "catholic", text: "Trent, Session 6: justification is real transformation, not a legal declaration only — grace makes the sinner actually righteous." },
      { src: "protestant", text: "Luther's breakthrough text: the righteousness of God is the righteousness by which he justifies us, not the standard by which he condemns us." },
      { src: "protestant", text: "The 1999 Joint Declaration on Justification found substantial Lutheran-Catholic agreement here, without erasing the remaining differences." },
      { src: "scofield", text: "Scofield (1917) distinguishes justification (a change in standing) from sanctification (a change in state), locating Romans 3 firmly in the first." },
      { src: "crossref", text: "Chain: Rom 3:21 → Hab 2:4 → Gen 15:6 → Rom 4:3 → Gal 2:16 → Phil 3:9." }
    ],
    consensus: {
      level: "red",
      verdict: "The most consequential disagreement in Western Christianity runs directly through these six verses. Real convergence since 1999, but the underlying question — is justification declared or imparted — is not settled.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "yellow", note: "Grace-centred and emphatic that salvation is a gift, but without the forensic precision the later debate demanded." },
        { name: "Catholic",  short: "CAT", level: "red",   note: "Trent anathematised the view that justification is imputation only. Justification includes real inward renewal." },
        { name: "Orthodox",  short: "ORT", level: "yellow", note: "Frames salvation as theosis rather than as a courtroom verdict, sidestepping the Western framing of the question." },
        { name: "Reformers", short: "REF", level: "red",   note: "Imputed, alien righteousness received by faith alone. The material principle of the entire Reformation." },
        { name: "Mainline",  short: "MLP", level: "yellow", note: "Largely Reformational in confession, and the main driver of the ecumenical convergence documents." },
        { name: "Evangelical", short: "EVA", level: "yellow", note: "Holds imputation firmly, but the New Perspective on Paul has reopened the question of what Paul meant by 'works of the law.'" }
      ]
    },
    scofield: {
      note: "Scofield defines justification as a judicial act in which God declares the believing sinner righteous, distinguishing it carefully from sanctification, which he treats as a subsequent and progressive work. He identifies the propitiation of verse 25 with the mercy seat of the tabernacle — the hilasterion of the Septuagint — so that the blood on the mercy seat becomes the type and the cross the fulfilment. He also marks this section as the transition from Paul's indictment (1:18-3:20) to his exposition of the gospel.",
      chain: ["Lev 16:14-15", "Hab 2:4", "Gen 15:6", "Gal 2:16", "Phil 3:9"],
      caution: null
    },
    cards: [
      { kind: "Cross-reference", text: "Hilasterion in verse 25 is the same Greek word the Septuagint uses for the mercy seat in Leviticus 16. Paul is saying the cross is where the blood is applied." },
      { kind: "Historical note", text: "Luther described his understanding of 'the righteousness of God' here as the moment the gates of paradise opened. Before it he read the phrase as God's demand; after it, as God's gift." },
      { kind: "Study prompt", text: "Verse 26 says God is both just and the justifier. What problem is Paul solving that requires both words in one sentence?" },
      { kind: "Artifact", text: "Erfurt Augustinian Monastery, where Luther worked through Romans", search: "Augustinian Monastery Erfurt Luther" }
    ]
  },

  /* ---------------------------------------------------------- */
  "rev-21": {
    ref: "Revelation 21:1-5",
    title: "New heaven, new earth — the end that is a beginning",
    verses: [1,2,3,4,5],
    translations: {
      ASV: {
        1: "And I saw a new heaven and a new earth: for the first heaven and the first earth are passed away; and the sea is no more.",
        2: "And I saw the holy city, new Jerusalem, coming down out of heaven of God, made ready as a bride adorned for her husband.",
        3: "And I heard a great voice out of the throne saying, Behold, the tabernacle of God is with men, and he shall dwell with them, and they shall be his peoples, and God himself shall be with them, and be their God:",
        4: "and he shall wipe away every tear from their eyes; and death shall be no more; neither shall there be mourning, nor crying, nor pain, any more: the first things are passed away.",
        5: "And he that sitteth on the throne said, Behold, I make all things new."
      },
      KJV: {
        1: "And I saw a new heaven and a new earth: for the first heaven and the first earth were passed away; and there was no more sea.",
        2: "And I John saw the holy city, new Jerusalem, coming down from God out of heaven, prepared as a bride adorned for her husband.",
        3: "And I heard a great voice out of heaven saying, Behold, the tabernacle of God is with men, and he will dwell with them, and they shall be his people, and God himself shall be with them, and be their God.",
        4: "And God shall wipe away all tears from their eyes; and there shall be no more death, neither sorrow, nor crying, neither shall there be any more pain: for the former things are passed away.",
        5: "And he that sat upon the throne said, Behold, I make all things new."
      }
    },
    diffNote: "Verse 3 holds a genuine textual difference, not just a stylistic one: ASV reads out of the throne and his peoples (plural), KJV reads out of heaven and his people (singular). The plural 'peoples' widens the covenant formula from Israel alone to the nations — a small change with large consequences for how you read the whole book.",
    ticker: [
      { src: "fathers", text: "Irenaeus, Against Heresies V: expects a renewed physical earth, not an escape from matter — the creation itself is redeemed." },
      { src: "fathers", text: "Augustine, City of God XX: shifts the reading toward the church's present age, a move that shaped Western eschatology for a thousand years." },
      { src: "catholic", text: "Catechism 1042-1050: the universe itself will be renewed, and the visible cosmos is destined to be transformed rather than discarded." },
      { src: "protestant", text: "Preterist readers take 'new heaven and new earth' as covenantal language for the new order after AD 70; futurists take it as literal cosmic renewal." },
      { src: "scofield", text: "Scofield (1917) reads this as the eternal state following the millennium and the great white throne — strictly literal and strictly future." },
      { src: "crossref", text: "Chain: Rev 21:1 → Isa 65:17-19 → Isa 25:8 → Ezek 37:27 → 2 Pet 3:13 → Rom 8:19-22." }
    ],
    consensus: {
      level: "green",
      verdict: "Strong agreement on the substance — God dwelling with a renewed humanity, death undone. The disagreement is over timing and literalness, not over the hope itself.",
      traditions: [
        { name: "Fathers",   short: "ECF", level: "yellow", note: "Irenaeus and the early chiliasts read it literally and materially; Origen and later Augustine read it spiritually." },
        { name: "Catholic",  short: "CAT", level: "green",  note: "Renewal of the cosmos affirmed; the millennium of chapter 20 read amillennially since Augustine." },
        { name: "Orthodox",  short: "ORT", level: "green",  note: "Central to the theology of the transfiguration of matter. Strongly anti-escapist." },
        { name: "Reformers", short: "REF", level: "green",  note: "Amillennial consensus; Calvin declined to comment on Revelation at all, but the Reformed confessions affirm the new creation." },
        { name: "Mainline",  short: "MLP", level: "green",  note: "Often read as the theological basis for creation care — the earth is renewed, not abandoned." },
        { name: "Evangelical", short: "EVA", level: "yellow", note: "Agreement on the outcome; sustained disagreement over whether a literal thousand-year reign precedes it." }
      ]
    },
    scofield: {
      note: "Scofield places these verses in the eternal state, after the thousand-year reign of chapter 20 and after the great white throne judgment. He reads the new heaven and new earth as literal, physical, and future, distinct from the millennial kingdom that precedes them, and he identifies the new Jerusalem as the dwelling of the glorified church, the bride, rather than as a symbol of the church's present condition. His chain-reference system threads this verse back through Isaiah's new-creation oracles.",
      chain: ["Isa 65:17-19", "Isa 66:22", "2 Pet 3:13", "Rev 20:11-15"],
      caution: "Preterist, historicist, and idealist readers all reject the strictly future-literal frame. See the four-lens comparison in the Revelation room."
    },
    cards: [
      { kind: "Cross-reference", text: "Isaiah 65:17 supplies the phrase itself. John is not inventing an image; he is finishing a sentence Isaiah started seven centuries earlier." },
      { kind: "Historical note", text: "'The sea is no more' would have read very differently on Patmos. For an exile, the sea was the thing separating him from everyone he loved — and in Revelation's imagery, the source of the beast." },
      { kind: "Study prompt", text: "Verse 3 uses the covenant formula from Ezekiel 37:27 almost verbatim. Why does the last chapter of the Bible reach for language that old?" },
      { kind: "Artifact", text: "Cave of the Apocalypse, Patmos", search: "Cave of the Apocalypse Patmos UNESCO" }
    ]
  }
};

/* Translations that exist but cannot be reproduced offline.
   The compare view renders these as a link-out column. */
window.V19_LICENSED = [
  { id: "NIV", name: "New International Version",
    why: "Copyright Biblica. Reproduction beyond brief quotation requires a licence.",
    url: "https://www.biblegateway.com/passage/?search={REF}&version=NIV" },
  { id: "NLT", name: "New Living Translation",
    why: "Copyright Tyndale House. Reproduction beyond brief quotation requires a licence.",
    url: "https://www.biblegateway.com/passage/?search={REF}&version=NLT" }
];
