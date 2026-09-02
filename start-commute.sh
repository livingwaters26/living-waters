#!/data/data/com.termux/files/usr/bin/bash
# Commute Companion — one-tap start script
#
# SETUP (do this once):
#   1. Install these from F-Droid (NOT the Play Store — those versions are outdated/broken):
#        - Termux
#        - Termux:Widget
#        - Termux:API   (optional, but lets this auto-open your browser)
#   2. In Termux, run:
#        pkg install python
#        pip install flask
#        mkdir -p ~/.shortcuts
#   3. Put this file at:  ~/.shortcuts/start-commute.sh
#      and make it executable:  chmod +x ~/.shortcuts/start-commute.sh
#   4. Copy your app folder (server.py, commute-companion.html, manifest.json, icon.svg)
#      into: ~/commute-companion-app/
#   5. Set your API key permanently so you don't retype it every time — run:
#        echo 'export ANTHROPIC_API_KEY=sk-ant-...your-key...' >> ~/.bashrc
#   6. Long-press your home screen -> Widgets -> find "Termux:Widget" -> add it.
#      It'll show "start-commute" as an option (from the filename) — tap to place it.
#
# FROM THEN ON: tap the widget. It checks if the server's already running (in case
# it never actually died), starts it if not, and opens the app in your browser.

source ~/.bashrc 2>/dev/null

APP_DIR=~/commute-companion-app
PORT=5000

# Is something already listening on the port? (server survived / already running)
if curl -s "http://localhost:$PORT" > /dev/null 2>&1; then
  echo "Already running — opening app."
else
  echo "Starting server..."
  cd "$APP_DIR" || { echo "App folder not found at $APP_DIR"; exit 1; }
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "⚠️  ANTHROPIC_API_KEY not set — add it to ~/.bashrc, see setup notes."
  fi
  nohup python server.py > ~/commute-companion.log 2>&1 &
  # give it a couple seconds to actually bind the port before we try to open it
  sleep 2
fi

# Open it. termux-open-url needs the Termux:API app installed; falls back to a
# manual message if it's not available.
if command -v termux-open-url > /dev/null 2>&1; then
  termux-open-url "http://localhost:$PORT"
else
  echo "Open your browser to http://localhost:$PORT"
fi
