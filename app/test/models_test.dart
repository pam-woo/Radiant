import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_app/data/models.dart';

void main() {
  test('LiveFrame parses what the simulator publishes', () {
    final frame = LiveFrame.fromJson({
      'intersectionId': 3,
      'name': 'Intersection 03',
      'mode': 'emergency',
      'modeLabel': 'EMERGENCY DETECTED',
      'lanes': [
        {
          'lane': 'north',
          'vehicleCount': 9,
          'signal': 'flashYellow',
          'secondsRemaining': null,
        },
        {
          'lane': 'south',
          'vehicleCount': 7,
          'signal': 'flashYellow',
          'secondsRemaining': null,
        },
        {
          'lane': 'east',
          'vehicleCount': 4,
          'signal': 'stop',
          'secondsRemaining': null,
        },
        {
          'lane': 'west',
          'vehicleCount': 3,
          'signal': 'stop',
          'secondsRemaining': 12,
        },
      ],
      'crosswalks': {
        'north': 'dontWalk',
        'south': 'dontWalk',
        'east': 'walk',
        'west': 'dontWalk',
      },
      'perceive': 'p',
      'decide': 'd',
      'act': 'a',
      'emergency': {'lane': 'west', 'headline': 'Ambulance coming from the WEST'},
    });

    expect(frame.intersectionId, 3);
    expect(frame.lane('north')!.signal, 'flashYellow');
    expect(frame.lane('west')!.secondsRemaining, 12);
    expect(frame.crosswalks['east'], 'walk');
    expect(frame.emergencyLane, 'west');
  });

  test('EventItem parses a database row', () {
    final event = EventItem.fromRow({
      'id': 7,
      'occurred_at': '2026-10-20T03:04:05+00:00',
      'intersection_id': 3,
      'lane': 'West',
      'type': 'emergencyDetected',
      'description': 'Flashing yellow, drivers alerted',
    });

    expect(event.id, 7);
    expect(event.intersectionId, 3);
    expect(event.lane, 'West');
    expect(event.occurredAt.toUtc().hour, 3);
  });

  test('IntersectionSummary parses a database row', () {
    final summary = IntersectionSummary.fromRow({
      'id': 1,
      'name': 'Intersection 01',
      'mode': 'idle',
      'vehicles_today': 1234,
      'emergency_alerts_today': 2,
    });

    expect(summary.mode, 'idle');
    expect(summary.vehiclesToday, 1234);
  });
}
