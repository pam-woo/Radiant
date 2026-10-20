import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_app/data/models.dart';

void main() {
  test('ActiveEmergency parses an active_emergencies row', () {
    final alert = ActiveEmergency.fromRow({
      'intersection_id': 3,
      'payload': {
        'intersectionName': 'Intersection 03',
        'lane': 'west',
        'vehicleType': 'ambulance',
        'distanceMeters': 300.0,
        'headline': 'Ambulance coming from the WEST',
        'distanceLabel': 'about 300 m away',
        'instruction': 'Move to the right side and stop, clear of the intersection.',
      },
      'updated_at': '2026-10-20T03:04:05+00:00',
    });

    expect(alert.intersectionId, 3);
    expect(alert.vehicleLabel, 'Ambulance');
    expect(alert.laneLabel, 'West');
    expect(alert.summary, 'Ambulance from the West, Intersection 03');
  });

  test('a fire truck is labelled as one', () {
    final alert = ActiveEmergency.fromRow({
      'intersection_id': 1,
      'payload': {
        'intersectionName': 'Intersection 01',
        'lane': 'north',
        'vehicleType': 'fireTruck',
        'distanceMeters': 120,
        'headline': 'Fire truck coming from the NORTH',
        'distanceLabel': 'about 100 m away',
        'instruction': 'Move over.',
      },
    });

    expect(alert.vehicleLabel, 'Fire truck');
    expect(alert.distanceMeters, 120.0);
  });
}
