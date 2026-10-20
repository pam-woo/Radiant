# Running Radiant, step by step

Radiant has three running parts: **Supabase** (shared data and login), the
**simulator** (writes the traffic to Supabase every second), and the **app**
(Android, read by admins and drivers).

## One-time setup

1. Install Flutter (it includes Dart) and Android Studio, with the Android SDK,
   Command-line Tools and the NDK. `flutter doctor` should show a green check for Android.
2. Create an Android emulator in Android Studio (Device Manager), or turn on USB
   debugging on a phone. `flutter devices` should list it.
3. Create a Supabase project, run `supabase/schema.sql` in its SQL Editor, turn
   off public sign-ups, and add the admin users (`supabase/README.md`).
4. Simulator key: in `simulator`, copy `.env.example` to `.env` and fill in
   `SUPABASE_URL` and the **secret** key. Never commit `.env`.
5. App key: in `app`, copy `env.example.json` to `env.json` and fill in the
   project URL and the **publishable** key.
6. Install packages once:
   ```
   cd packages\radiant_core ; dart pub get
   cd ..\..\simulator ; dart pub get
   cd ..\app ; flutter pub get
   ```

## Every time you run it

1. **Start the emulator** (or plug in the phone) and wait for the Android home screen.
2. **Terminal 1, the data:**
   ```
   cd C:\src\radiant\simulator
   dart run bin/run.dart --emergency-boost 10
   ```
   Wait about 90 seconds for the silent warm-up. Leave it running.
   (`--emergency-boost 10` makes emergency vehicles frequent, for demos.)
3. **Terminal 2, the app:**
   ```
   cd C:\src\radiant\app
   flutter run --dart-define-from-file=env.json
   ```
   Or install the release APK (below), which is smoother.
4. **As an authorized user:** tap Sign in, use an admin account. Monitor shows the
   live intersection; the pill at the top switches intersections; Event Log has
   filters and "View live monitor"; Settings has display options and Sign out.
5. **As a driver:** from Settings choose Switch user type (or sign out), then
   Continue as driver. The Event Log shows summaries; an alert opens by itself
   when an emergency vehicle approaches (tap Got it to close).
6. **To stop:** press Ctrl+C in terminal 1 (it clears active emergencies) and `q`
   in terminal 2.

## Optional: drive an intersection from detections

See `detector/README.md`. Quick try with the synthetic sample:
```
dart run bin/run.dart --replay replay/sample_detections.jsonl --replay-intersection 1
```

## Build the release APK

```
cd C:\src\radiant\app
flutter build apk --release --dart-define-from-file=env.json
```
The file is `build\app\outputs\flutter-apk\app-release.apk`. Install it by
dragging it onto the emulator window, or copy it to a phone and open it
(allow "install unknown apps"). It contains only the publishable key.

## Checks

```
cd packages\radiant_core ; dart test
cd ..\..\simulator ; dart test
cd ..\app ; flutter analyze ; flutter test
cd ..\detector ; python -m unittest discover -s tests
```

## When something is wrong

- **"Waiting for live data":** the simulator is not running, or you are not signed in as an admin.
- **"No connection" banner:** no fresh data for 12 seconds. Check terminal 1 and the internet.
- **Simulator says it cannot reach Supabase:** check `.env`, and that `schema.sql` was run.
- **Sign-in fails:** wrong password, or the user does not exist or is not confirmed in Supabase.
- **"System UI isn't responding" on the emulator:** the emulator is short of
  memory. Close Android Studio and other programs, give the emulator 4 GB RAM,
  use an API 34 image, or use a phone. A release APK runs lighter than `flutter run`.
- **GitHub rejects a push for a secret:** a real key is in a tracked file. Keep keys
  only in `.env` and `env.json`, remove them from the commit, and never click "allow".
