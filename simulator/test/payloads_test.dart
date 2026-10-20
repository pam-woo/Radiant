import 'package:radiant_core/radiant_core.dart';
import 'package:radiant_simulator/payloads.dart';
import 'package:test/test.dart';

void main() {
  test('rows use the column names that supabase/schema.sql defines', () {
    final sim = TrafficSimulator(seed: 1);
    final now = DateTime.utc(2026, 10, 19, 9);
    var sawEvent = false;
    var sawEmergency = false;

    for (var i = 0; i < 3600; i++) {
      final frames = sim.tick();

      final summaries = intersectionRows(frames, now);
      expect(summaries, hasLength(5));
      expect(
        summaries.first.keys,
        containsAll([
          'id',
          'name',
          'mode',
          'vehicles_today',
          'emergency_alerts_today',
          'updated_at',
        ]),
      );
      expect(['normal', 'emergency', 'idle'], contains(summaries.first['mode']));

      final live = liveRows(frames, now);
      expect(live, hasLength(5));
      final frame = live.first['frame'] as Map<String, dynamic>;
      expect(frame.containsKey('events'), isFalse);
      expect(frame['lanes'], hasLength(4));

      for (final row in eventRows(frames)) {
        sawEvent = true;
        expect(
          row.keys,
          containsAll(
              ['occurred_at', 'intersection_id', 'lane', 'type', 'description']),
        );
        expect(
          [
            'densityAdjust',
            'emergencyDetected',
            'idleMode',
            'pedestrianCrossing',
          ],
          contains(row['type']),
        );
      }

      for (final row in emergencyRows(frames, now)) {
        sawEmergency = true;
        final payload = row['payload'] as Map<String, dynamic>;
        expect(payload['headline'], contains('coming from the'));
        expect(payload['notificationBody'], isNotEmpty);
      }
    }

    expect(sawEvent, isTrue);
    expect(sawEmergency, isTrue);
  });
}
