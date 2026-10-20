# radiant_simulator

Runs the traffic simulation from `radiant_core` in real time and publishes it to
Supabase, so the admin and driver phones all see the same live state.

## Setup

```powershell
cd C:\src\radiant\simulator
Copy-Item .env.example .env      # then edit .env with your URL and SECRET key
dart pub get
dart test
```

## Run

```powershell
dart run bin/run.dart                 # until Ctrl+C
dart run bin/run.dart --seconds 120   # two minutes
dart run bin/run.dart --seed 7        # different random traffic
dart run bin/run.dart --warmup 0      # skip the 90 s silent warm-up
dart run bin/run.dart --emergency-boost 10   # ten times as many emergency vehicles
```

It first simulates 90 seconds silently so the roads are already busy when
the first phone connects. Each start clears old events and active emergencies for a clean demo. Stop it
when you are not demoing: it sends a few requests every second.

The `.env` file holds the secret key and is ignored by git. Never commit it.
