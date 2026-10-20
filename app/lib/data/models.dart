// Plain data classes parsed from what the simulator publishes to Supabase.

class IntersectionSummary {
  const IntersectionSummary({
    required this.id,
    required this.name,
    required this.mode,
    required this.vehiclesToday,
    required this.emergencyAlertsToday,
  });

  final int id;
  final String name;

  /// "normal", "emergency" or "idle".
  final String mode;
  final int vehiclesToday;
  final int emergencyAlertsToday;

  factory IntersectionSummary.fromRow(Map<String, dynamic> row) {
    return IntersectionSummary(
      id: row['id'] as int,
      name: row['name'] as String,
      mode: row['mode'] as String,
      vehiclesToday: row['vehicles_today'] as int,
      emergencyAlertsToday: row['emergency_alerts_today'] as int,
    );
  }
}

class LaneInfo {
  const LaneInfo({
    required this.lane,
    required this.vehicleCount,
    required this.signal,
    this.secondsRemaining,
  });

  /// "north", "south", "east" or "west".
  final String lane;
  final int vehicleCount;

  /// "go", "yellow", "stop" or "flashYellow".
  final String signal;
  final int? secondsRemaining;

  factory LaneInfo.fromJson(Map<String, dynamic> json) {
    return LaneInfo(
      lane: json['lane'] as String,
      vehicleCount: json['vehicleCount'] as int,
      signal: json['signal'] as String,
      secondsRemaining: json['secondsRemaining'] as int?,
    );
  }
}

/// One full live snapshot of an intersection (admin only).
class LiveFrame {
  const LiveFrame({
    required this.intersectionId,
    required this.name,
    required this.mode,
    required this.lanes,
    required this.crosswalks,
    required this.perceive,
    required this.decide,
    required this.act,
    this.emergency,
  });

  final int intersectionId;
  final String name;
  final String mode;
  final List<LaneInfo> lanes;

  /// lane name -> "dontWalk", "walk" or "free".
  final Map<String, String> crosswalks;
  final String perceive;
  final String decide;
  final String act;
  final Map<String, dynamic>? emergency;

  factory LiveFrame.fromJson(Map<String, dynamic> json) {
    return LiveFrame(
      intersectionId: json['intersectionId'] as int,
      name: json['name'] as String,
      mode: json['mode'] as String,
      lanes: [
        for (final l in json['lanes'] as List)
          LaneInfo.fromJson(Map<String, dynamic>.from(l as Map)),
      ],
      crosswalks: Map<String, String>.from(json['crosswalks'] as Map),
      perceive: json['perceive'] as String,
      decide: json['decide'] as String,
      act: json['act'] as String,
      emergency: json['emergency'] == null
          ? null
          : Map<String, dynamic>.from(json['emergency'] as Map),
    );
  }

  LaneInfo? lane(String name) {
    for (final l in lanes) {
      if (l.lane == name) return l;
    }
    return null;
  }

  String? get emergencyLane => emergency?['lane'] as String?;
}

class EventItem {
  const EventItem({
    required this.id,
    required this.occurredAt,
    required this.intersectionId,
    required this.lane,
    required this.type,
    required this.description,
  });

  final int id;
  final DateTime occurredAt;
  final int intersectionId;

  /// "North", "East, West" or "All".
  final String lane;

  /// "densityAdjust", "emergencyDetected", "idleMode" or "pedestrianCrossing".
  final String type;
  final String description;

  factory EventItem.fromRow(Map<String, dynamic> row) {
    return EventItem(
      id: row['id'] as int,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
      intersectionId: row['intersection_id'] as int,
      lane: row['lane'] as String,
      type: row['type'] as String,
      description: row['description'] as String,
    );
  }
}

/// An emergency vehicle currently approaching an intersection (public data,
/// what drivers see).
class ActiveEmergency {
  const ActiveEmergency({
    required this.intersectionId,
    required this.intersectionName,
    required this.lane,
    required this.vehicleType,
    required this.distanceMeters,
    required this.headline,
    required this.distanceLabel,
    required this.instruction,
  });

  final int intersectionId;
  final String intersectionName;

  /// The side it is coming from: "north", "south", "east" or "west".
  final String lane;

  /// "ambulance" or "fireTruck".
  final String vehicleType;
  final double distanceMeters;
  final String headline;
  final String distanceLabel;
  final String instruction;

  factory ActiveEmergency.fromRow(Map<String, dynamic> row) {
    final p = Map<String, dynamic>.from(row['payload'] as Map);
    return ActiveEmergency(
      intersectionId: row['intersection_id'] as int,
      intersectionName: p['intersectionName'] as String,
      lane: p['lane'] as String,
      vehicleType: p['vehicleType'] as String,
      distanceMeters: (p['distanceMeters'] as num).toDouble(),
      headline: p['headline'] as String,
      distanceLabel: p['distanceLabel'] as String,
      instruction: p['instruction'] as String,
    );
  }

  String get vehicleLabel => vehicleType == 'fireTruck' ? 'Fire truck' : 'Ambulance';

  String get laneLabel =>
      lane.isEmpty ? lane : lane[0].toUpperCase() + lane.substring(1);

  /// "Ambulance from the West, Intersection 03"
  String get summary => '$vehicleLabel from the $laneLabel, $intersectionName';
}
