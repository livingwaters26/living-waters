# Start Here (very simple instructions)

You do **not** need to know Dart or programming to get this running.  
Just follow these steps one by one on your own computer (Windows, Mac, or Linux).

---

## 1. Install Flutter (one-time setup)

Flutter is the tool that turns this code into an Android app.

1. Go to this website on your computer:  
   https://docs.flutter.dev/get-started/install
2. Choose your operating system (Windows / macOS / Linux).
3. Follow the official instructions (they have pictures).
4. When it asks you to install Android Studio, say yes — that is what lets the app run on an Android phone or tablet.
5. At the end, open a terminal / command prompt and type:

```
flutter doctor
```

Fix anything it says is missing (it will tell you exactly what to click).

---

## 2. Open this project

1. Copy the whole `commute_notes` folder to your computer (Downloads, Desktop, anywhere).
2. Open a terminal **inside** that folder.
3. Type these commands, one after the other:

```
flutter create .
flutter pub get
flutter run
```

- `flutter create .` fills in the Android project files Flutter needs (keep our existing `lib` folder if it asks).
- `flutter pub get` downloads the extra pieces.
- `flutter run` builds the app and tries to launch it.

If you have an Android phone plugged in with USB debugging turned on, the app will install on your phone.  
If not, it can open in an Android emulator (a fake phone on your computer).

---

## 3. What you will see right now

- A home screen that says “No audio files yet”
- A big button to choose MP3 files (you can select many at once)
- After you import an MP3 you can create a labeled Session
- Inside a Session the **Play button actually plays the audio**
- Mute works, the progress bar works, and it remembers where you left off
- You can record a voice note (it keeps the short clip) or type a note
- Notes show up in a list; tapping one jumps the player to that moment

The only big pieces still missing are the scrolling captions and turning your spoken notes into text automatically.

---

## 4. What is still being built

- Scrolling captions that follow the scripture audio
- Automatic transcription of your voice notes
- A clean export / outline button so you can bring the notes back here for insight

You do **not** have to write any of that code.  
Just keep the project folder and run `flutter run` again after more pieces are added.

---

## Need help?

When something goes wrong, copy the exact error message and paste it back here.  
I will tell you the next simple step.
