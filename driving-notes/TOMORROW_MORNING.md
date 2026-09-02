# Do this tomorrow morning (about 15–30 minutes)

You only need to do these steps on your computer. Everything else is already built.

---

## Step 1 – Install Flutter (only if you haven’t)

1. Open: https://docs.flutter.dev/get-started/install
2. Pick Windows or Mac.
3. Follow the pictures until `flutter doctor` looks mostly green.
4. Install Android Studio when it asks.

---

## Step 2 – Put the project on your computer

Copy the whole `commute_notes` folder somewhere easy (Desktop or Documents).

---

## Step 3 – Build and run

Open a terminal **inside** the `commute_notes` folder and run these three commands one at a time:

```
flutter create .
```

(If it asks about overwriting files, keep the existing `lib` folder and `pubspec.yaml`.)

```
flutter pub get
```

```
flutter run
```

- Phone plugged in with USB debugging on → app installs on your phone.  
- No phone → it can open a fake phone (emulator) on the computer.

---

## Step 4 – First use on the phone

1. Tap **Choose MP3 Files**
2. Go to the folder with your scripture MP3s and select one or more
3. Tap **Import**
4. Open the file → **New Session** → give it a name (example: “John 3 – Morning”)
5. Tap Play – audio should play
6. Tap the mic to record a note, or Type note
7. Use Mute if you need silence
8. Top-right list icon = Export / copy notes for Grok

---

## What works tomorrow

- Import MP3s  
- Labeled sessions  
- Play / pause / seek / mute  
- Resume where you left off  
- Voice notes (saves the clip) + typed notes  
- Captions that move with the audio (placeholder text until we add real Whisper)  
- Phone-call pause (auto-pauses and frees the mic)  
- Export notes to paste here  

## Real scripture captions

Whisper is wired into the app:

1. First use may download the **base** model (~60–75 MB) — use **Wi‑Fi**.
2. In the player, tap the **CC** icon → **Generate real captions**.
3. Keep the phone plugged in; wait a few minutes for a long chapter.
4. After that, captions show the actual words. Spoken notes also turn into text when you stop the mic.

If Whisper errors on first build, the rest of the app still works. Paste the full error here and we’ll fix it.

---

If anything errors, copy the **full red error message** and send it here. I’ll tell you the exact next click.
