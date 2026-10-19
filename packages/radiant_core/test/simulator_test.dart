import 'dart:convert';

import 'package:radiant_core/radiant_core.dart';
import 'package:test/test.dart';

void main() {
  test('the same seed gives exactly the same simulation', () {
    String run(int seed) {
      final sim = TrafficSimulator(seed: seed);
      final out = StringBuffer();
      for (var i = 0; i < 300; i++) {
        for (final f in sim.tick()) {
          out.write(jsonEncode(f.toJson()));
        }
      }
      return out.toString();
    }

    expect(run(7), run(7));
    expect(run(7), isNot(run(8)));
  });

  test('Intersection 04 (empty road) goes idle and stays idle', () {
    final sim = TrafficSimulator(seed: 3);
    for (var i = 1; i <= 300; i++) {
      final frame =
          sim.tick().firstWhere((f) => f.intersectionId == 4);
      if (i >= 6) {
        expect(frame.mode, IntersectionMode.idle, reason: 'tick $i');
      }
    }
    expect(sim.intersections[3].vehiclesToday, 0);
  });

  test('safety and timing invariants hold for an hour on every intersection',
      () {
    final sim = TrafficSimulator(seed: 1, maxEvents: 1000000);
    const config = AgentConfig();

    // Per intersection id and per axis lane (north, east).
    final yellowRun = <int, Map<Lane, int>>{};
    final greenRun = <int, Map<Lane, int>>{};
    var sawEmergencyEvent = false;

    for (var tick = 0; tick < 3600; tick++) {
      for (final f in sim.tick()) {
        final signals = {for (final l in f.lanes) l.lane: l.signal};

        for (final l in f.lanes) {
          expect(l.vehicleCount, inInclusiveRange(0, 26));
        }

        if (f.mode != IntersectionMode.idle) {
          final nsActive = signals[Lane.north] != SignalState.stop;
          final ewActive = signals[Lane.east] != SignalState.stop;
          expect(nsActive && ewActive, isFalse,
              reason: 'conflicting signals at ${f.name}, tick $tick');
        } else {
          for (final lane in Lane.values) {
            expect(f.crosswalks[lane], CrosswalkState.free);
          }
        }

        final anyYellow = signals.values.contains(SignalState.yellow);
        for (final entry in f.crosswalks.entries) {
          if (entry.value == CrosswalkState.walk) {
            expect(signals[entry.key], SignalState.stop);
            expect(anyYellow, isFalse);
          }
        }

        // Yellow lasts exactly yellowSeconds; green lasts at least minGreen
        // before it turns yellow.
        final yellows = yellowRun.putIfAbsent(
            f.intersectionId, () => {Lane.north: 0, Lane.east: 0});
        final greens = greenRun.putIfAbsent(
            f.intersectionId, () => {Lane.north: 0, Lane.east: 0});

        for (final lane in [Lane.north, Lane.east]) {
          final s = signals[lane]!;

          if (s == SignalState.yellow) {
            if (f.mode != IntersectionMode.idle && greens[lane]! > 0) {
              expect(greens[lane]!, greaterThanOrEqualTo(config.minGreenSeconds),
                  reason: '${f.name} $lane green too short');
            }
            greens[lane] = 0;
            yellows[lane] = yellows[lane]! + 1;
          } else {
            if (yellows[lane]! > 0) {
              expect(yellows[lane], config.yellowSeconds,
                  reason: '${f.name} $lane yellow length');
            }
            yellows[lane] = 0;
            final isGreenLike = f.mode != IntersectionMode.idle &&
                (s == SignalState.go || s == SignalState.flashYellow);
            greens[lane] = isGreenLike ? greens[lane]! + 1 : 0;
          }
        }

        if (f.events.any((e) => e.type == EventType.emergencyDetected)) {
          sawEmergencyEvent = true;
        }
      }
    }

    expect(sawEmergencyEvent, isTrue);

    final emergencyEvents =
        sim.events.where((e) => e.type == EventType.emergencyDetected).length;
    final counted = sim.intersections
        .fold<int>(0, (sum, i) => sum + i.emergencyAlertsToday);
    expect(counted, emergencyEvents);

    expect(sim.intersections.first.vehiclesToday, greaterThan(0));
  });
}
