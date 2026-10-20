import 'package:radiant_core/radiant_core.dart';
import 'package:test/test.dart';

const _jsonl = '''
{"t":0,"counts":{"north":2,"south":1,"east":0,"west":3}}

{"t":1,"counts":{"north":2,"south":1,"east":0,"west":4},"emergency":{"lane":"west","type":"ambulance","confidence":0.93}}
{"t":2,"counts":{"north":0,"south":0,"east":1,"west":1},"emergency":{"lane":"north","type":"fire_truck","confidence":0.8}}
''';

void main() {
  group('parsing', () {
    test('reads JSON Lines and skips blank lines', () {
      final frames = ReplayFrame.parseJsonLines(_jsonl);

      expect(frames, hasLength(3));
      expect(frames[0].counts[Lane.west], 3);
      expect(frames[0].emergency, isNull);
      expect(frames[1].emergency!.lane, Lane.west);
      expect(frames[1].emergency!.vehicleType, EmergencyVehicleType.ambulance);
      expect(frames[1].emergency!.confidence, 0.93);
    });

    test('accepts fire_truck, fireTruck and Fire truck', () {
      for (final type in ['fire_truck', 'fireTruck', 'Fire truck']) {
        final e = ReplayEmergency.fromJson(
          {'lane': 'east', 'type': type, 'confidence': 0.9},
        );
        expect(e.vehicleType, EmergencyVehicleType.fireTruck, reason: type);
      }
    });

    test('rejects an unknown lane', () {
      expect(
        () => ReplayEmergency.fromJson(
          {'lane': 'up', 'type': 'ambulance', 'confidence': 0.9},
        ),
        throwsFormatException,
      );
    });
  });

  group('ReplayIntersection', () {
    final t0 = DateTime.utc(2026, 10, 20);

    test('drives the agent and derives the emergency distance', () {
      final busy = {Lane.north: 5, Lane.south: 4, Lane.east: 1, Lane.west: 1};
      final withAmbulance = {
        Lane.north: 5,
        Lane.south: 4,
        Lane.east: 1,
        Lane.west: 2,
      };
      const ambulance = ReplayEmergency(
        lane: Lane.west,
        vehicleType: EmergencyVehicleType.ambulance,
        confidence: 0.9,
      );
      final frames = [
        for (var i = 0; i < 3; i++) ReplayFrame(counts: busy),
        for (var i = 0; i < 3; i++)
          ReplayFrame(counts: withAmbulance, emergency: ambulance),
      ];

      final replay = ReplayIntersection(id: 9, name: 'Test', frames: frames);
      final out = [
        for (var i = 0; i < 6; i++) replay.step(t0.add(Duration(seconds: i))),
      ];

      expect(out[2].mode, IntersectionMode.normal);
      expect(out[3].mode, IntersectionMode.emergency);
      expect(out[3].emergency!.detection.distanceMeters, 300);
      expect(out[4].emergency!.detection.distanceMeters, 285);
      expect(replay.emergencyAlertsToday, 1);
      expect(replay.vehiclesToday, greaterThan(0));
    });

    test('loops when the recording ends', () {
      final replay = ReplayIntersection(
        id: 9,
        name: 'Test',
        frames: [
          ReplayFrame(counts: {Lane.north: 1}),
          ReplayFrame(counts: {Lane.north: 2}),
        ],
      );

      for (var i = 0; i < 7; i++) {
        expect(
          () => replay.step(t0.add(Duration(seconds: i))),
          returnsNormally,
        );
      }
    });

    test('works inside TrafficSimulator next to random intersections', () {
      final sources = <IntersectionSource>[
        ...TrafficSimulator.defaultIntersections(1),
      ];
      sources[0] = ReplayIntersection(
        id: 1,
        name: 'Intersection 01',
        frames: [ReplayFrame(counts: {Lane.east: 3, Lane.west: 2})],
      );

      final sim = TrafficSimulator(seed: 1, intersections: sources);
      final frames = sim.tick();

      expect(frames, hasLength(5));
      expect(frames.first.intersectionId, 1);
    });
  });
}
