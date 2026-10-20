import 'dart:convert';

import 'models.dart';
import 'simulator.dart';
import 'traffic_agent.dart';

/// An emergency vehicle reported by the detector for one second.
class ReplayEmergency {
  const ReplayEmergency({
    required this.lane,
    required this.vehicleType,
    required this.confidence,
  });

  final Lane lane;
  final EmergencyVehicleType vehicleType;
  final double confidence;

  factory ReplayEmergency.fromJson(Map<String, dynamic> json) {
    final lane = Lane.values.asNameMap()[json['lane'] as String];
    if (lane == null) {
      throw FormatException('Unknown lane: ${json['lane']}');
    }
    // Accepts "fire_truck", "fireTruck", "Fire truck" and so on.
    final type =
        (json['type'] as String).toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return ReplayEmergency(
      lane: lane,
      vehicleType: type == 'firetruck'
          ? EmergencyVehicleType.fireTruck
          : EmergencyVehicleType.ambulance,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

/// One second of detector output: what the camera and classifier saw.
class ReplayFrame {
  const ReplayFrame({
    required this.counts,
    this.pedestrians = const {},
    this.emergency,
  });

  final Map<Lane, int> counts;
  final Map<Lane, int> pedestrians;
  final ReplayEmergency? emergency;

  factory ReplayFrame.fromJson(Map<String, dynamic> json) {
    final emergency = json['emergency'];
    return ReplayFrame(
      counts: _laneInts(json['counts']),
      pedestrians: _laneInts(json['pedestrians']),
      emergency: emergency == null
          ? null
          : ReplayEmergency.fromJson(Map<String, dynamic>.from(emergency as Map)),
    );
  }

  /// Parses a JSON Lines file: one JSON object per second, blank lines ignored.
  static List<ReplayFrame> parseJsonLines(String text) {
    final frames = <ReplayFrame>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      frames.add(
        ReplayFrame.fromJson(Map<String, dynamic>.from(jsonDecode(line) as Map)),
      );
    }
    return frames;
  }
}

Map<Lane, int> _laneInts(Object? raw) {
  final result = <Lane, int>{};
  if (raw is Map) {
    final lanes = Lane.values.asNameMap();
    for (final entry in raw.entries) {
      final lane = lanes[entry.key as String];
      if (lane != null) result[lane] = (entry.value as num).toInt();
    }
  }
  return result;
}

/// Feeds the agent from recorded detector output instead of random traffic.
///
/// The detector reports counts and emergency vehicles but not distance, so
/// distance is derived: it starts at [startDistanceMeters] when the vehicle
/// is first seen and shrinks at [speedMetersPerSecond].
class ReplayIntersection implements IntersectionSource {
  ReplayIntersection({
    required this.id,
    required this.name,
    required this.frames,
    AgentConfig agentConfig = const AgentConfig(),
    this.startDistanceMeters = 300,
    this.speedMetersPerSecond = 15,
  })  : assert(frames.isNotEmpty),
        agent = TrafficAgent(intersectionId: id, config: agentConfig);

  @override
  final int id;
  @override
  final String name;

  final List<ReplayFrame> frames;
  final TrafficAgent agent;
  final double startDistanceMeters;
  final double speedMetersPerSecond;

  /// Vehicles the camera has seen arrive (increases in the lane counts).
  @override
  int vehiclesToday = 0;
  @override
  int emergencyAlertsToday = 0;

  int _index = 0;
  int _emergencySeconds = 0;
  Lane? _emergencyLane;
  final Map<Lane, int> _previous = {};

  @override
  IntersectionFrame step(DateTime now) {
    // The recording loops when it reaches the end.
    final frame = frames[_index % frames.length];
    _index++;

    EmergencyDetection? detection;
    final seen = frame.emergency;
    if (seen != null) {
      if (_emergencyLane != seen.lane) _emergencySeconds = 0;
      _emergencyLane = seen.lane;
      final distance =
          startDistanceMeters - speedMetersPerSecond * _emergencySeconds;
      _emergencySeconds++;
      detection = EmergencyDetection(
        lane: seen.lane,
        vehicleType: seen.vehicleType,
        confidence: seen.confidence,
        distanceMeters: distance < 0 ? 0.0 : distance,
      );
    } else {
      _emergencyLane = null;
      _emergencySeconds = 0;
    }

    final percept = Percept(
      intersectionId: id,
      vehicleCounts: frame.counts,
      pedestriansWaiting: frame.pedestrians,
      emergency: detection,
    );
    final decision = agent.step(percept, now);

    for (final lane in Lane.values) {
      final current = percept.count(lane);
      final before = _previous[lane] ?? 0;
      if (current > before) vehiclesToday += current - before;
      _previous[lane] = current;
    }
    for (final event in decision.events) {
      if (event.type == EventType.emergencyDetected) emergencyAlertsToday++;
    }

    return IntersectionFrame(
      intersectionId: id,
      name: name,
      time: now,
      mode: decision.mode,
      lanes: [for (final l in Lane.values) decision.lanes[l]!],
      crosswalks: decision.crosswalks,
      perceive: decision.perceive,
      decide: decision.decide,
      act: decision.act,
      vehiclesToday: vehiclesToday,
      emergencyAlertsToday: emergencyAlertsToday,
      events: decision.events,
      emergency: detection == null
          ? null
          : EmergencyAlert(
              intersectionId: id,
              intersectionName: name,
              detection: detection,
            ),
    );
  }
}
