import 'package:radiant_core/radiant_core.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 19, 8);

Percept percept({
  int n = 0,
  int s = 0,
  int e = 0,
  int w = 0,
  EmergencyDetection? emergency,
  Map<Lane, int>? peds,
}) =>
    Percept(
      intersectionId: 1,
      vehicleCounts: {Lane.north: n, Lane.south: s, Lane.east: e, Lane.west: w},
      pedestriansWaiting: peds,
      emergency: emergency,
    );

AgentDecision stepAt(TrafficAgent agent, int second, Percept p) =>
    agent.step(p, t0.add(Duration(seconds: second)));

SignalState signal(AgentDecision d, Lane lane) => d.lanes[lane]!.signal;

bool hasEvent(AgentDecision d, EventType type) =>
    d.events.any((e) => e.type == type);

const westAmbulance = EmergencyDetection(
  lane: Lane.west,
  vehicleType: EmergencyVehicleType.ambulance,
  confidence: 0.96,
  distanceMeters: 300,
);

void main() {
  group('signal timing', () {
    test('holds green 5 s, then exactly 3 s yellow, then the other direction',
        () {
      final agent = TrafficAgent(intersectionId: 1);

      // North-South is busier at the start, so it gets the first green.
      var d = stepAt(agent, 1, percept(n: 10));
      expect(signal(d, Lane.north), SignalState.go);

      // Everyone leaves North-South and East-West fills up, but the 5 s
      // minimum green must still be honoured.
      for (var i = 2; i <= 5; i++) {
        d = stepAt(agent, i, percept(e: 10));
        expect(signal(d, Lane.north), SignalState.go, reason: 'second $i');
      }

      // Seconds 6, 7 and 8 are yellow.
      for (var i = 6; i <= 8; i++) {
        d = stepAt(agent, i, percept(e: 10));
        expect(signal(d, Lane.north), SignalState.yellow, reason: 'second $i');
        expect(signal(d, Lane.east), SignalState.stop, reason: 'second $i');
      }

      // Second 9: East-West goes.
      d = stepAt(agent, 9, percept(e: 10));
      expect(signal(d, Lane.north), SignalState.stop);
      expect(signal(d, Lane.east), SignalState.go);
      expect(signal(d, Lane.west), SignalState.go);
    });

    test('the busier waiting direction takes over when the planned green ends',
        () {
      final agent = TrafficAgent(intersectionId: 1);
      // Planned green for 3 vehicles is 8 s.
      var d = stepAt(agent, 1, percept(n: 3));
      var sawYellow = false;
      for (var i = 2; i <= 12; i++) {
        d = stepAt(agent, i, percept(n: 3, e: 9));
        if (signal(d, Lane.north) == SignalState.yellow) sawYellow = true;
      }
      expect(sawYellow, isTrue);
    });

    test('a busy direction cannot starve a quiet one', () {
      final agent = TrafficAgent(intersectionId: 1);
      var longestStop = 0;
      var currentStop = 0;
      var eastWentGreen = false;

      for (var i = 1; i <= 600; i++) {
        final d = stepAt(agent, i, percept(n: 20, e: 1));
        if (signal(d, Lane.east) == SignalState.stop) {
          currentStop++;
          if (currentStop > longestStop) longestStop = currentStop;
        } else {
          currentStop = 0;
        }
        if (signal(d, Lane.east) == SignalState.go) eastWentGreen = true;
      }

      expect(eastWentGreen, isTrue);
      // 40 s maximum green + 3 s yellow, with a little slack.
      expect(longestStop, lessThanOrEqualTo(50));
    });
  });

  group('idle intersection', () {
    test('flashes yellow after being empty, pedestrians cross freely', () {
      final agent = TrafficAgent(intersectionId: 1);
      AgentDecision d = stepAt(agent, 1, percept());

      for (var i = 2; i <= 4; i++) {
        d = stepAt(agent, i, percept());
        expect(d.mode, IntersectionMode.normal, reason: 'second $i');
      }

      d = stepAt(agent, 5, percept());
      expect(d.mode, IntersectionMode.idle);
      expect(hasEvent(d, EventType.idleMode), isTrue);
      for (final lane in Lane.values) {
        expect(signal(d, lane), SignalState.flashYellow);
        expect(d.crosswalks[lane], CrosswalkState.free);
      }
    });

    test('a vehicle ends idle mode through a 3 s yellow, never straight to red',
        () {
      final agent = TrafficAgent(intersectionId: 1);
      for (var i = 1; i <= 5; i++) {
        stepAt(agent, i, percept());
      }

      // North-South is busier, so East-West (which was flashing) gets the
      // yellow, and North-South gets its green afterwards.
      var d = stepAt(agent, 6, percept(n: 2));
      expect(d.mode, IntersectionMode.normal);
      expect(hasEvent(d, EventType.densityAdjust), isTrue);
      expect(signal(d, Lane.east), SignalState.yellow);
      expect(signal(d, Lane.north), SignalState.stop);

      d = stepAt(agent, 7, percept(n: 2));
      expect(signal(d, Lane.east), SignalState.yellow);
      d = stepAt(agent, 8, percept(n: 2));
      expect(signal(d, Lane.east), SignalState.yellow);

      d = stepAt(agent, 9, percept(n: 2));
      expect(signal(d, Lane.north), SignalState.go);
      expect(signal(d, Lane.east), SignalState.stop);
    });
  });

  group('emergency vehicle', () {
    test('busiest lanes flash yellow, drivers are alerted once', () {
      final agent = TrafficAgent(intersectionId: 1);
      final withEmergency =
          percept(n: 9, s: 7, e: 4, w: 3, emergency: westAmbulance);

      var d = stepAt(agent, 1, withEmergency);
      expect(d.mode, IntersectionMode.emergency);
      expect(signal(d, Lane.north), SignalState.flashYellow);
      expect(signal(d, Lane.south), SignalState.flashYellow);
      expect(signal(d, Lane.east), SignalState.stop);
      expect(signal(d, Lane.west), SignalState.stop);

      final alerts =
          d.events.where((e) => e.type == EventType.emergencyDetected).toList();
      expect(alerts, hasLength(1));
      expect(alerts.first.laneLabel, 'West');
      expect(d.perceive, contains('Ambulance in the West lane (96%)'));

      // Still approaching: no second alert.
      d = stepAt(agent, 2, withEmergency);
      expect(hasEvent(d, EventType.emergencyDetected), isFalse);
      expect(d.mode, IntersectionMode.emergency);

      // Vehicle has passed: normal cycle resumes.
      d = stepAt(agent, 3, percept(n: 9, s: 7, e: 4, w: 3));
      expect(d.mode, IntersectionMode.normal);
      expect(signal(d, Lane.north), SignalState.go);
      expect(hasEvent(d, EventType.densityAdjust), isTrue);
    });

    test('driver alert texts match the design', () {
      const alert = EmergencyAlert(
        intersectionId: 3,
        intersectionName: 'Intersection 03',
        detection: westAmbulance,
      );
      expect(alert.headline, 'Ambulance coming from the WEST');
      expect(alert.distanceLabel, 'about 300 m away');
      expect(alert.notificationBody,
          startsWith('Ambulance from the West at Intersection 03.'));
    });
  });

  group('pedestrians', () {
    test('walk only across stopped lanes, and the crossing is logged once', () {
      final agent = TrafficAgent(intersectionId: 1);
      final p = percept(n: 10, peds: {Lane.east: 3, Lane.north: 2});

      var d = stepAt(agent, 1, p);
      expect(d.crosswalks[Lane.east], CrosswalkState.walk);
      expect(d.crosswalks[Lane.north], CrosswalkState.dontWalk);
      expect(d.crosswalks[Lane.west], CrosswalkState.dontWalk);

      final walkEvents =
          d.events.where((e) => e.type == EventType.pedestrianCrossing);
      expect(walkEvents, hasLength(1));
      expect(walkEvents.first.laneLabel, 'East, West');

      d = stepAt(agent, 2, p);
      expect(hasEvent(d, EventType.pedestrianCrossing), isFalse);
    });
  });
}
