# Radiant

Agent-based adaptive traffic signal and emergency vehicle prioritization
(CS 403 Intelligent Agents). Android app built with Flutter, simulated data,
Supabase for shared live state and authentication.

## Layout

```
packages/radiant_core/   agent, simulator, shared models (pure Dart)   <- step 1
supabase/                schema and security rules                      <- step 2
simulator/               script that writes the simulation to Supabase  <- step 2
app/                     Flutter Android app                            <- steps 3-6
```

Never commit Supabase keys. Put them in a local `.env` (already in `.gitignore`).
