"""
Study Hub — server v2
Serves the whole static site (Scripture Studies, Doctrine, Topics, Commentary, Tools,
Journal, etc.) AND powers the Commute Companion's AI chat + the multi-plan reading
system + the "Save to My Study" journal.

SETUP:
  1. pip install flask anthropic
  2. export ANTHROPIC_API_KEY=your-key-here   (get one at console.anthropic.com)
  3. python server.py
  4. Open http://localhost:5000 in your browser — this is now the WHOLE site, not
     just Commute Companion. The companion lives at /tools/commute-companion.html.
  5. On your phone: browse to your computer's local IP (e.g. http://192.168.1.x:5000)
     while on the same wifi, then "Add to Home Screen" on the commute-companion page
     for a real icon.

For a permanent setup (works away from home wifi too), deploy this to any small
host (Render, Railway, a Raspberry Pi with port forwarding, etc.).
"""

import os
import json
import uuid
import urllib.request
import urllib.error
from datetime import date, datetime, timedelta

from flask import Flask, request, jsonify, send_from_directory, abort

SITE_ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SITE_ROOT, 'data')
PLANS_DIR = os.path.join(DATA_DIR, 'plans')
JOURNAL_DIR = os.path.join(DATA_DIR, 'journal')
ENTRIES_FILE = os.path.join(JOURNAL_DIR, 'entries.json')
JOURNAL_PAGE_DIR = os.path.join(SITE_ROOT, 'journal')

app = Flask(__name__, static_folder=None)

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"

WEEKDAY_ABBR = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']


# ---------------------------------------------------------------------------
# Static site serving — the whole site, not just one page
# ---------------------------------------------------------------------------

@app.route('/')
def index():
    return send_from_directory(SITE_ROOT, 'index.html')


@app.route('/<path:filepath>')
def static_files(filepath):
    # Guard against escaping SITE_ROOT
    full = os.path.normpath(os.path.join(SITE_ROOT, filepath))
    if not full.startswith(SITE_ROOT):
        abort(403)
    if not os.path.isfile(full):
        abort(404)
    directory, filename = os.path.split(full)
    return send_from_directory(directory, filename)


# ---------------------------------------------------------------------------
# Chat proxy (unchanged from v1) — holds the API key server-side
# ---------------------------------------------------------------------------

@app.route('/api/chat', methods=['POST'])
def chat():
    if not ANTHROPIC_API_KEY:
        return jsonify({"error": "Server is missing ANTHROPIC_API_KEY. Set it and restart."}), 500

    payload = request.get_json()

    req = urllib.request.Request(
        ANTHROPIC_URL,
        data=json.dumps(payload).encode('utf-8'),
        headers={
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read()
            return app.response_class(body, mimetype='application/json')
    except urllib.error.HTTPError as e:
        return app.response_class(e.read(), status=e.code, mimetype='application/json')


# ---------------------------------------------------------------------------
# Plans — generalized multi-plan reading system
# ---------------------------------------------------------------------------

def _load_plan_file(fname):
    with open(os.path.join(PLANS_DIR, fname), 'r', encoding='utf-8') as f:
        return json.load(f)


def _list_plan_files():
    if not os.path.isdir(PLANS_DIR):
        return []
    return sorted(f for f in os.listdir(PLANS_DIR) if f.endswith('.json'))


def compute_current_session(plan):
    """Daily cadence: straight day-count since start_date.
    Non-daily (e.g. 4x/week) cadence: count actual meeting-day occurrences
    since start_date, not calendar days — a Tue/Thu/Sat/Sun group doesn't
    advance a session on a Wednesday."""
    sessions = plan.get('sessions', [])
    n = len(sessions)
    if n == 0:
        return 1
    try:
        start = datetime.strptime(plan['start_date'], '%Y-%m-%d').date()
    except (KeyError, ValueError):
        return 1
    today = date.today()
    if today < start:
        return 1

    if plan.get('cadence') == 'daily':
        idx = (today - start).days + 1
    else:
        meeting_days = set(plan.get('meeting_days', []))
        idx = 0
        d = start
        while d <= today:
            if WEEKDAY_ABBR[d.weekday()] in meeting_days:
                idx += 1
            d += timedelta(days=1)

    return max(1, min(idx, n))


@app.route('/api/plans', methods=['GET'])
def list_plans():
    out = []
    for fname in _list_plan_files():
        try:
            plan = _load_plan_file(fname)
        except (json.JSONDecodeError, OSError):
            continue
        out.append({
            "plan_id": plan.get("plan_id"),
            "name": plan.get("name"),
            "description": plan.get("description", ""),
            "cadence": plan.get("cadence"),
            "session_count": len(plan.get("sessions", [])),
            "current_session": compute_current_session(plan),
        })
    return jsonify({"plans": out})


@app.route('/api/plans/<plan_id>', methods=['GET'])
def get_plan(plan_id):
    for fname in _list_plan_files():
        try:
            plan = _load_plan_file(fname)
        except (json.JSONDecodeError, OSError):
            continue
        if plan.get("plan_id") == plan_id:
            plan["current_session"] = compute_current_session(plan)
            return jsonify(plan)
    return jsonify({"error": "Plan not found: " + plan_id}), 404


def _slugify(text):
    slug = ''.join(c.lower() if c.isalnum() else '-' for c in text.strip())
    while '--' in slug:
        slug = slug.replace('--', '-')
    return slug.strip('-') or 'plan'


@app.route('/api/plans/save', methods=['POST'])
def save_plan():
    payload = request.get_json(force=True, silent=True) or {}

    name = (payload.get('name') or '').strip()
    if not name:
        return jsonify({"error": "name is required"}), 400

    sessions = payload.get('sessions') or []
    if not isinstance(sessions, list) or len(sessions) == 0:
        return jsonify({"error": "sessions must be a non-empty list"}), 400

    cadence = payload.get('cadence') or 'custom'
    start_date = payload.get('start_date') or date.today().isoformat()
    try:
        datetime.strptime(start_date, '%Y-%m-%d')
    except ValueError:
        return jsonify({"error": "start_date must be YYYY-MM-DD"}), 400

    meeting_days = payload.get('meeting_days') or (WEEKDAY_ABBR if cadence == 'daily' else [])
    bad_days = [d for d in meeting_days if d not in WEEKDAY_ABBR]
    if bad_days:
        return jsonify({"error": "meeting_days must be from " + str(WEEKDAY_ABBR) + ", got " + str(bad_days)}), 400

    plan_id = (payload.get('plan_id') or '').strip() or _slugify(name)
    plan_id = _slugify(plan_id)

    # normalize sessions: require a session number and a readings list per entry
    norm_sessions = []
    for i, s in enumerate(sessions):
        if not isinstance(s, dict):
            return jsonify({"error": "each session must be an object"}), 400
        readings = s.get('readings')
        if isinstance(readings, str):
            readings = [r.strip() for r in readings.split(',') if r.strip()]
        norm_sessions.append({
            "session": s.get('session', i + 1),
            "title": s.get('title', ''),
            "readings": readings or [],
            "notes": s.get('notes', ''),
        })

    plan = {
        "plan_id": plan_id,
        "name": name,
        "description": payload.get('description', ''),
        "cadence": cadence,
        "start_date": start_date,
        "meeting_days": meeting_days,
        "sessions": norm_sessions,
    }

    os.makedirs(PLANS_DIR, exist_ok=True)
    fpath = os.path.join(PLANS_DIR, plan_id + '.json')
    is_new = not os.path.isfile(fpath)
    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(plan, f, indent=2, ensure_ascii=False)

    plan["current_session"] = compute_current_session(plan)
    return jsonify({"ok": True, "created": is_new, "plan": plan})


# ---------------------------------------------------------------------------
# Journal — "Save to My Study" + archive (nothing is ever deleted)
# ---------------------------------------------------------------------------

def _load_entries():
    if not os.path.isfile(ENTRIES_FILE):
        return []
    with open(ENTRIES_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


def _save_entries(entries):
    os.makedirs(JOURNAL_DIR, exist_ok=True)
    with open(ENTRIES_FILE, 'w', encoding='utf-8') as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)


def _esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _entry_card_html(entry, back_prefix="../"):
    refs = " · ".join(entry.get("refs", []))
    date_str = entry.get("date_saved", "")[:10]
    summary_snip = _esc(entry.get("summary", ""))
    return f'''<div class="ilm-card" style="cursor:default;">
<div class="ilm-card-eyebrow">{_esc(entry.get("plan_id",""))} · Session {entry.get("session","")} · {_esc(date_str)}</div>
<h3>{_esc(refs)}</h3>
<p>{summary_snip}</p>
</div>'''


def _page_shell(title, subtitle, body_html, back_prefix="../"):
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>{_esc(title)} — Study Hub</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,600;1,9..144,500;1,9..144,600&family=Source+Serif+4:opsz,wght@8..60,400;8..60,500;8..60,600&family=Space+Grotesk:wght@400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{back_prefix}lib/illuminated.css">
</head>
<body class="ilm ilm-bg-full">
  <section class="ilm-hero">
    <div class="ilm-eyebrow">Study Hub</div>
    <div class="ilm-numeral">✦</div>
    <h1 class="ilm-h1">{_esc(title)}</h1>
    <div class="ilm-subtitle">{_esc(subtitle)}</div>
    <div class="ilm-rule"></div>
  </section>
  <div class="ilm-index-wrap">
    <div style="margin-bottom:20px;"><a href="{back_prefix}index.html" style="font-family:var(--ilm-font-ui);font-size:0.8rem;color:var(--ilm-gold-soft);text-decoration:none;">← back to hub</a></div>
    {body_html}
  </div>
  <footer class="ilm-footer">
    <div class="ilm-colophon">Carved from the Blue Ridge</div>
  </footer>
<script src="{back_prefix}lib/illuminated.js"></script>
</body>
</html>'''


def render_journal_pages():
    entries = _load_entries()
    live = [e for e in entries if not e.get("archived")]
    archived = [e for e in entries if e.get("archived")]

    live_sorted = sorted(live, key=lambda e: e.get("date_saved", ""), reverse=True)
    if live_sorted:
        grid = '<div class="ilm-grid">' + "".join(_entry_card_html(e) for e in live_sorted) + '</div>'
    else:
        grid = '<p style="font-family:var(--ilm-font-body);color:var(--ilm-on-dark-soft);">Nothing saved yet — end a Commute Companion discussion and tap "Save to My Study" to start your journal.</p>'
    if archived:
        grid += '<div style="margin-top:34px;"><a href="archive.html" style="font-family:var(--ilm-font-ui);font-size:0.8rem;color:var(--ilm-gold-soft);text-decoration:none;">View archived entries →</a></div>'

    os.makedirs(JOURNAL_PAGE_DIR, exist_ok=True)
    with open(os.path.join(JOURNAL_PAGE_DIR, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(_page_shell("My Study Journal", "Saved discussions from Commute Companion, kept exactly as you left them.", grid))

    # Archive, grouped by year
    by_year = {}
    for e in archived:
        year = (e.get("date_saved", "")[:4]) or "Unknown"
        by_year.setdefault(year, []).append(e)
    if by_year:
        sections = []
        for year in sorted(by_year.keys(), reverse=True):
            year_entries = sorted(by_year[year], key=lambda e: e.get("date_saved", ""), reverse=True)
            cards = "".join(_entry_card_html(e) for e in year_entries)
            sections.append(f'<h2 style="font-family:var(--ilm-font-display);color:var(--ilm-glow);margin:30px 0 6px;">{year}</h2><div class="ilm-grid">{cards}</div>')
        archive_body = "".join(sections)
    else:
        archive_body = '<p style="font-family:var(--ilm-font-body);color:var(--ilm-on-dark-soft);">No archived entries yet. Archiving moves entries here, off the live index — nothing is ever deleted.</p>'

    with open(os.path.join(JOURNAL_PAGE_DIR, 'archive.html'), 'w', encoding='utf-8') as f:
        f.write(_page_shell("Journal Archive", "Older saved entries, kept — never deleted.", archive_body))


@app.route('/api/journal/save', methods=['POST'])
def journal_save():
    payload = request.get_json(force=True, silent=True) or {}
    plan_id = payload.get('plan_id')
    session = payload.get('session')
    if not plan_id or session is None:
        return jsonify({"error": "plan_id and session are required"}), 400

    entry = {
        "id": uuid.uuid4().hex[:12],
        "plan_id": plan_id,
        "session": session,
        "refs": payload.get('refs', []),
        "date_saved": datetime.now().isoformat(timespec='seconds'),
        "summary": payload.get('summary', ''),
        "commentary": payload.get('commentary', ''),
        "archived": False,
    }
    entries = _load_entries()
    entries.append(entry)
    _save_entries(entries)
    render_journal_pages()
    return jsonify({"ok": True, "entry": entry})


@app.route('/api/journal/archive', methods=['POST'])
def journal_archive():
    payload = request.get_json(force=True, silent=True) or {}
    entry_id = payload.get('id')
    if not entry_id:
        return jsonify({"error": "id is required"}), 400

    entries = _load_entries()
    found = False
    for e in entries:
        if e.get('id') == entry_id:
            e['archived'] = True
            found = True
            break
    if not found:
        return jsonify({"error": "No entry with id " + entry_id}), 404

    _save_entries(entries)
    render_journal_pages()
    return jsonify({"ok": True})


if __name__ == '__main__':
    if not ANTHROPIC_API_KEY:
        print("\n⚠️  ANTHROPIC_API_KEY is not set. The app will load but chat won't work until you set it.\n")
    os.makedirs(JOURNAL_DIR, exist_ok=True)
    render_journal_pages()  # make sure journal/index.html + archive.html exist on first boot
    app.run(host='0.0.0.0', port=5000, debug=True)
