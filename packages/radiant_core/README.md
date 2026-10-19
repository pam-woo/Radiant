# radiant_core

Pure Dart package (no Flutter, no UI) with the parts of Radiant that are not
screens:

- `lib/src/models.dart` data types: lanes, signals, events, emergency alerts,
  and `IntersectionFrame` (one full snapshot of an intersection per second).
- `lib/src/traffic_agent.dart` the intelligent agent.
- `lib/src/simulator.dart` the fake camera/detector feed for Intersections 01-05.
- `bin/simulate.dart` command-line runner.
- `test/` unit and invariant tests.

## Run

```
dart pub get
dart test
dart run bin/simulate.dart --intersection 3 --seconds 120 --explain
```

Other examples: `--intersection 4` (empty road), `--intersection 5` (pedestrians),
`--seconds 600 --seed 7`, `--realtime`.

## How the agent decides (once per second)

1. **Perceive** lane counts, an emergency detection (lane, type, confidence,
   distance) and pedestrians waiting.
2. **Decide** from lane density with a 5 s minimum green, a 3 s yellow, a 40 s
   maximum green and a 60 s maximum wait, so no direction starves.
3. **Act** by setting signals, crosswalks and writing events.

Special cases:

- Emergency vehicle: timing is unchanged. The busiest (green) lanes flash
  yellow and drivers are alerted. Nothing is forced red.
- Empty intersection (5 s with no vehicles): all approaches flash yellow and
  pedestrians cross freely. When a vehicle arrives, the direction that will
  wait gets a 3 s yellow first.
- Intersection 05 style pedestrians: walk is only shown across a stopped lane,
  never during yellow and not in the last 4 s of a planned green.

## Assumptions to confirm

- During an emergency, crosswalks keep following the normal rules.
- Vehicles-today counts vehicles that passed and is not reset at midnight.
- Emergency rates per hour are demo values (01: 12, 02: 12, 03: 20, 05: 8).
