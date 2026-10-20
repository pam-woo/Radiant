import 'package:radiant_core/radiant_core.dart';

/// Turns simulator frames into rows that match `supabase/schema.sql`.
/// Pure functions, so they can be tested without a network.

String _iso(DateTime t) => t.toUtc().toIso8601String();

/// Summary cards (public). Table: intersections.
List<Map<String, dynamic>> intersectionRows(
  List<IntersectionFrame> frames,
  DateTime now,
) =>
    [
      for (final f in frames)
        {
          'id': f.intersectionId,
          'name': f.name,
          'mode': f.mode.name,
          'vehicles_today': f.vehiclesToday,
          'emergency_alerts_today': f.emergencyAlertsToday,
          'updated_at': _iso(now),
        },
    ];

/// Full live snapshot (admin only). Table: intersection_live.
/// The tick's events are left out because they go to the events table.
List<Map<String, dynamic>> liveRows(
  List<IntersectionFrame> frames,
  DateTime now,
) =>
    [
      for (final f in frames)
        {
          'intersection_id': f.intersectionId,
          'frame': f.toJson()..remove('events'),
          'updated_at': _iso(now),
        },
    ];

/// New Event Log entries. Table: events.
List<Map<String, dynamic>> eventRows(List<IntersectionFrame> frames) => [
      for (final f in frames)
        for (final e in f.events)
          {
            'occurred_at': _iso(e.time),
            'intersection_id': e.intersectionId,
            'lane': e.laneLabel,
            'type': e.type.name,
            'description': e.description,
          },
    ];

/// Intersections that currently have an emergency vehicle approaching.
/// Table: active_emergencies.
List<Map<String, dynamic>> emergencyRows(
  List<IntersectionFrame> frames,
  DateTime now,
) =>
    [
      for (final f in frames)
        if (f.emergency != null)
          {
            'intersection_id': f.intersectionId,
            'payload': f.emergency!.toJson(),
            'updated_at': _iso(now),
          },
    ];
