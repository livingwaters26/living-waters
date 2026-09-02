# Android permissions (add these when the app is fully generated)

When you first run `flutter create .` (or open the project in Android Studio), Flutter will create the `android` folder.

Then open this file:

`android/app/src/main/AndroidManifest.xml`

Inside the `<manifest> ... </manifest>` section, add these lines near the top (before `<application>`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Only needed if you later read files outside the app sandbox -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
```

On newer Android versions the system will still ask the user for microphone permission the first time they record a note. That is normal and correct.

You do **not** need to do this until you are ready to test voice notes on a real phone.
