# Radiant

Agent-based adaptive traffic signal and emergency vehicle prioritization
(CS 403 Intelligent Agents). Android app built with Flutter, simulated traffic,
Supabase for shared live state and authentication.

## Layout

```
packages/radiant_core/   agent, simulator, replay, shared models (pure Dart)
supabase/                schema and security rules
simulator/               script that publishes the simulation to Supabase
app/                     Flutter Android app (admin and driver)
detector/                Python pipeline: Roboflow dataset to detections
docs/                    RUNNING.md (how to run it) and DEMO.md
```

Start with `docs/RUNNING.md`.

Never commit Supabase keys. They live only in `simulator/.env` and `app/env.json`
(both ignored by git).
