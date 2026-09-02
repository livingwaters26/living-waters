FORCE overwrite for player_screen.dart
=====================================

1. Unzip this into:
   C:\src\driving_notes\lib\

2. It will replace only:
   lib\screens\player_screen.dart

What this fixes:
- "Commute Notes" → "Driving Notes" in the microphone permission dialog
- Reading box height 260 → 310 (one extra line of text)
- Notes list height 220 → 160 (so the transport buttons are more likely visible without scrolling much)

3. Then do a FULL clean rebuild from C:\src\driving_notes:
   C:\src\flutter\bin\flutter.bat clean
   pause
   C:\src\flutter\bin\flutter.bat pub get
   pause
   C:\src\flutter\bin\flutter.bat run --release -d R52YA02836J
