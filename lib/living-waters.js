/* Living Waters — shared behavior: photo backdrop, rotating carousel, live ticker content, voice/read-aloud. */

// Confirmed U.S. Forest Service (public-domain, government-work) photos of the immediate
// Murphy, NC / North Georgia area. Short list on purpose — see LW_CC_IMAGES below for how
// to responsibly add more variety without mislabeling licensing.
var LW_PD_IMAGES = [
  {
    url: 'https://commons.wikimedia.org/wiki/Special:FilePath/Fires%20Creek%20Recreation%20Area%20in%20the%20Nantahala%20National%20Forest%20in%20Clay%20County%2C%20North%20Carolina.jpg',
    credit: 'Fires Creek, Nantahala National Forest — Clay County, NC (bordering Murphy) · U.S. Forest Service, public domain'
  },
  {
    url: 'https://commons.wikimedia.org/wiki/Special:FilePath/Brasstown%20Bald%20Visit.jpg',
    credit: 'Brasstown Bald, Georgia\u2019s highest point — ~25 min from Murphy · U.S. Forest Service, public domain'
  }
];

// Creative Commons (attribution-required, NOT public domain) images — off by default.
// Flip LW_USE_CC_IMAGES to true in a page if you want more rotation variety; each entry
// keeps its real photographer credit rather than being relabeled as public domain.
var LW_CC_IMAGES = [
  {
    url: 'https://commons.wikimedia.org/wiki/Special:FilePath/Whitewater%20falls%201.jpg',
    credit: 'Whitewater Falls, Nantahala National Forest, NC · Wikimedia Commons, CC BY-SA'
  },
  {
    url: 'https://commons.wikimedia.org/wiki/Special:FilePath/Chatuge%20Sunset%20-%20panoramio.jpg',
    credit: 'Lake Chatuge, Hiawassee, GA (straddles the NC/GA line by Murphy) · Wikimedia Commons, CC BY'
  }
];
var LW_USE_CC_IMAGES = true;

// Reserved slots for the user's own local photos — see data/photos/README.md.
// Until a file exists at that path, the slot shows a labeled on-brand placeholder
// instead of a broken image, so the rotation always looks intentional.
var LW_LOCAL_IMAGES = [
  { url: 'data/photos/local-01.jpg', credit: 'Your photo', placeholderLabel: 'A waterfall you\u2019ve visited' },
  { url: 'data/photos/local-02.jpg', credit: 'Your photo', placeholderLabel: 'Lake Chatuge, your favorite spot' },
  { url: 'data/photos/local-03.jpg', credit: 'Your photo', placeholderLabel: 'Sunrise or sunset over the mountains' },
  { url: 'data/photos/local-04.jpg', credit: 'Your photo', placeholderLabel: 'A trail, overlook, or gap view' },
  { url: 'data/photos/local-05.jpg', credit: 'Your photo', placeholderLabel: 'Any season \u2014 fall color, snow, spring green' },
  { url: 'data/photos/local-06.jpg', credit: 'Your photo', placeholderLabel: 'Whatever else you like' }
];

function lwActiveImageSet() {
  var webImages = LW_USE_CC_IMAGES ? LW_PD_IMAGES.concat(LW_CC_IMAGES) : LW_PD_IMAGES;
  return webImages.concat(LW_LOCAL_IMAGES);
}

function lwInitBackdrop(containerId) {
  var container = document.getElementById(containerId || 'lw-backdrop');
  if (!container) return;
  var images = lwActiveImageSet();
  if (images.length === 0) return;

  var slideEls = images.map(function (im, i) {
    var slide = document.createElement('div');
    slide.className = 'lw-slide';
    slide.style.cssText = 'position:absolute;inset:0;opacity:0;transition:opacity 2.5s ease-in-out;';

    var img = document.createElement('img');
    img.src = im.url;
    img.alt = '';
    img.loading = i === 0 ? 'eager' : 'lazy';
    img.style.cssText = 'width:100%;height:100%;object-fit:cover;';

    var placeholder = null;
    if (im.placeholderLabel) {
      placeholder = document.createElement('div');
      placeholder.style.cssText = 'display:none;width:100%;height:100%;align-items:center;justify-content:center;text-align:center;' +
        'background:linear-gradient(135deg, rgba(20,184,166,0.16) 0%, rgba(4,13,10,0.9) 70%);';
      placeholder.innerHTML = '<div style="max-width:320px;padding:0 20px;">' +
        '<div style="font-size:1.6rem;margin-bottom:8px;opacity:0.6;">🏔️</div>' +
        '<div style="font-family:\'Plus Jakarta Sans\',sans-serif;font-size:0.78rem;color:rgba(241,245,249,0.55);letter-spacing:0.02em;line-height:1.5;">' +
        'Your photo here \u2014 ' + im.placeholderLabel + '</div></div>';
      placeholder.style.display = 'flex';
    }

    img.onload = function () { img.style.display = 'block'; if (placeholder) placeholder.style.display = 'none'; };
    img.onerror = function () {
      img.style.display = 'none';
      if (placeholder) { placeholder.style.display = 'flex'; }
      else { slide.dataset.deadHotlink = '1'; } // sourced image with no placeholder — just skip it silently
    };

    slide.appendChild(img);
    if (placeholder) slide.appendChild(placeholder);
    container.appendChild(slide);
    return { slide: slide, meta: im };
  });

  var creditEl = document.getElementById('lw-photo-credit');
  var idx = 0;
  function show(i) {
    slideEls.forEach(function (s, j) { s.slide.style.opacity = (j === i) ? '1' : '0'; });
    if (creditEl) creditEl.textContent = slideEls[i].meta.credit;
  }
  show(0);
  if (slideEls.length > 1) {
    setInterval(function () {
      idx = (idx + 1) % slideEls.length;
      show(idx);
    }, 12000);
  }
}

// Generic rotating carousel — pass an array of {tag, title, body} and element ids.
function lwInitCarousel(items, els, msPerItem) {
  if (!items || items.length === 0) return;
  var tagEl = document.getElementById(els.tag);
  var titleEl = document.getElementById(els.title);
  var bodyEl = document.getElementById(els.body);
  var progressEl = document.getElementById(els.progress);
  var i = 0;
  var duration = msPerItem || 8000;

  function render() {
    if (tagEl) tagEl.textContent = items[i].tag;
    if (titleEl) titleEl.textContent = items[i].title;
    if (bodyEl) bodyEl.textContent = items[i].body;
  }
  render();

  var elapsed = 0;
  var tick = 100;
  setInterval(function () {
    elapsed += tick;
    if (progressEl) progressEl.style.width = Math.min(100, (elapsed / duration) * 100) + '%';
    if (elapsed >= duration) {
      elapsed = 0;
      i = (i + 1) % items.length;
      render();
    }
  }, tick);
}

// Builds a marquee <span> list from plain strings (icon optional via {icon, text}).
function lwBuildMarquee(elId, entries) {
  var el = document.getElementById(elId);
  if (!el) return;
  var spansOnce = entries.map(function (e) {
    var icon = e.icon ? '<i class="' + e.icon + ' mr-2"></i>' : '';
    return '<span class="mr-16">' + icon + e.text + '</span>';
  }).join('');
  el.innerHTML = spansOnce + spansOnce; // duplicated for seamless marquee loop
}

// Fetches live plan data and returns a plain-language "today" string for the ticker/hero.
async function lwFetchTodayReading() {
  try {
    var res = await fetch('/api/plans');
    var data = await res.json();
    var plans = data.plans || [];
    if (plans.length === 0) return null;
    var primary = plans[0];
    var detailRes = await fetch('/api/plans/' + encodeURIComponent(primary.plan_id));
    var detail = await detailRes.json();
    var session = (detail.sessions || []).find(function (s) { return s.session === detail.current_session; });
    if (!session) return null;
    return {
      planName: detail.name,
      sessionLabel: detail.cadence === 'daily' ? 'Day' : 'Session',
      sessionNum: session.session,
      title: session.title,
      readings: session.readings || []
    };
  } catch (e) {
    return null;
  }
}

function lwReadAloud(elId) {
  var el = document.getElementById(elId);
  if (!el || !('speechSynthesis' in window)) { if (!('speechSynthesis' in window)) alert('Text-to-speech is not supported in this browser.'); return; }
  window.speechSynthesis.cancel();
  var u = new SpeechSynthesisUtterance(el.innerText);
  u.rate = 0.95; u.pitch = 0.95;
  window.speechSynthesis.speak(u);
}
