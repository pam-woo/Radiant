# radiant_app

Flutter Android app for Radiant.

- Step 3: role selection, driver notification permission, authorized user sign-in.
- Step 4: admin Monitor and Event Log, live from Supabase, with empty and
  "no connection" states.
- Step 5: driver Event Log, the emergency banner, and the full-screen alert that
  opens automatically when an emergency vehicle approaches.
- Step 6: Settings and accessibility, saved on the device: emergency alerts,
  alert sound and vibration (driver), high-contrast mode, text size, and
  color-blind-safe signals (icons and shapes), plus screen reader labels.

The Monitor needs the simulator running: `dart run bin/run.dart` in `simulator`.

## One-time setup

```powershell
cd C:\src\radiant\app
flutter create --platforms=android --org ph.edu.tip --project-name radiant_app .
Copy-Item env.example.json env.json      # then fill in env.json
flutter pub get
```

Then add two lines to `android\app\src\main\AndroidManifest.xml`, directly under
the line that starts with `<manifest`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

(Optional) change `android:label="radiant_app"` to `android:label="Radiant"`.

## Run

Start the emulator first, then:

```powershell
flutter run --dart-define-from-file=env.json
```

`env.json` holds the Supabase URL and the publishable (anon) key. It is ignored
by git. Never put the secret key here.

## Check

```powershell
flutter analyze
flutter test
```
