/// Core domain types shared by the agent, the simulator and (later) the app.
///
/// Everything here is plain Dart so the same code can run in the Flutter app
/// and in the command-line simulator.

enum Lane { north, south, east, west }

enum Axis { northSouth, eastWest }

extension LaneInfo on Lane {
  String get label => switch (this) {
        Lane.north => 'North',
        Lane.south => 'South',
        Lane.east => 'East',
        Lane.west => 'West',
      };

  String get initial => label[0];

  Axis get axis => (this == Lane.north || this == Lane.south)
      ? Axis.northSouth
      : Axis.eastWest;
}

extension AxisInfo on Axis {
  String get label => this == Axis.northSouth ? 'North-South' : 'East-West';

  Axis get other => this == Axis.northSouth ? Axis.eastWest : Axis.northSouth;

  List<Lane> get lanes => this == Axis.northSouth
      ? const [Lane.north, Lane.south]
      : const [Lane.east, Lane.west];

  String get laneLabels => lanes.map((l) => l.label).join(', ');
}

enum SignalState { go, yellow, stop, flashYellow }

extension SignalStateInfo on SignalState {
  String get label => switch (this) {
        SignalState.go => 'GO',
        SignalState.yellow => 'YELLOW',
        SignalState.stop => 'STOP',
        SignalState.flashYellow => 'FLASH YELLOW',
      };
}

enum CrosswalkState { dontWalk, walk, free }

enum IntersectionMode { normal, emergency, idle }

extension IntersectionModeInfo on IntersectionMode {
  String get label => switch (this) {
        IntersectionMode.normal => 'NORMAL',
        IntersectionMode.emergency => 'EMERGENCY DETECTED',
        IntersectionMode.idle => 'IDLE',
      };
}

enum EmergencyVehicleType { ambulance, fireTruck }

extension EmergencyVehicleTypeInfo on EmergencyVehicleType {
  String get label => switch (this) {
        EmergencyVehicleType.ambulance => 'Ambulance',
        EmergencyVehicleType.fireTruck => 'Fire truck',
      };
}

enum EventType {
  densityAdjust,
  emergencyDetected,
  idleMode,
  pedestrianCrossing,
}

extension EventTypeInfo on EventType {
  String get label => switch (this) {
        EventType.densityAdjust => 'DENSITY ADJUST',
        EventType.emergencyDetected => 'EMERGENCY DETECTED',
        EventType.idleMode => 'IDLE MODE',
        EventType.pedestrianCrossing => 'PEDESTRIAN CROSSING',
      };
}

/// What the (simulated) camera + classifier reports about an emergency vehicle.
class EmergencyDetection {
  const EmergencyDetection({
    required this.lane,
    required this.vehicleType,
    required this.confidence,
    required this.distanceMeters,
  });

  /// The side the vehicle is approaching from.
  final Lane lane;
  final EmergencyVehicleType vehicleType;

  /// Classifier confidence from 0.0 to 1.0.
  final double confidence;
  final double distanceMeters;

  EmergencyDetection withDistance(double meters) => EmergencyDetection(
        lane: lane,
        vehicleType: vehicleType,
        confidence: confidence,
        distanceMeters: meters,
      );

  Map<String, dynamic> toJson() => {
        'lane': lane.name,
        'vehicleType': vehicleType.name,
        'confidence': confidence,
        'distanceMeters': distanceMeters,
      };
}

/// Everything the agent senses in one tick (one second).
class Percept {
  Percept({
    required this.intersectionId,
    required Map<Lane, int> vehicleCounts,
    Map<Lane, int>? pedestriansWaiting,
    this.emergency,
  })  : vehicleCounts = Map<Lane, int>.unmodifiable({
          for (final l in Lane.values) l: vehicleCounts[l] ?? 0,
        }),
        pedestriansWaiting = Map<Lane, int>.unmodifiable({
          for (final l in Lane.values) l: pedestriansWaiting?[l] ?? 0,
        });

  final int intersectionId;

  /// Vehicles per lane. An approaching emergency vehicle is counted too.
  final Map<Lane, int> vehicleCounts;

  /// Pedestrians waiting at the crosswalk across each lane's road.
  final Map<Lane, int> pedestriansWaiting;

  final EmergencyDetection? emergency;

  int count(Lane lane) => vehicleCounts[lane]!;

  int axisDensity(Axis axis) =>
      axis.lanes.fold(0, (sum, lane) => sum + count(lane));

  int get totalVehicles =>
      axisDensity(Axis.northSouth) + axisDensity(Axis.eastWest);

  int pedestriansOn(Axis axis) =>
      axis.lanes.fold(0, (sum, lane) => sum + pedestriansWaiting[lane]!);
}

/// What one lane card on the Monitor screen shows.
class LaneStatus {
  const LaneStatus({
    required this.lane,
    required this.vehicleCount,
    required this.signal,
    this.secondsRemaining,
  });

  final Lane lane;
  final int vehicleCount;
  final SignalState signal;

  /// Countdown for GO and YELLOW. Null when there is no countdown to show.
  final int? secondsRemaining;

  Map<String, dynamic> toJson() => {
        'lane': lane.name,
        'vehicleCount': vehicleCount,
        'signal': signal.name,
        'secondsRemaining': secondsRemaining,
      };
}

/// One entry in the Event Log.
class TrafficEvent {
  const TrafficEvent({
    required this.time,
    required this.intersectionId,
    required this.laneLabel,
    required this.type,
    required this.description,
  });

  final DateTime time;
  final int intersectionId;

  /// "North", "East, West" or "All".
  final String laneLabel;
  final EventType type;
  final String description;

  Map<String, dynamic> toJson() => {
        'time': time.toUtc().toIso8601String(),
        'intersectionId': intersectionId,
        'lane': laneLabel,
        'type': type.name,
        'description': description,
      };
}

/// What a driver sees for an approaching emergency vehicle.
class EmergencyAlert {
  const EmergencyAlert({
    required this.intersectionId,
    required this.intersectionName,
    required this.detection,
  });

  final int intersectionId;
  final String intersectionName;
  final EmergencyDetection detection;

  Lane get lane => detection.lane;

  String get headline =>
      '${detection.vehicleType.label} coming from the ${lane.label.toUpperCase()}';

  String get distanceLabel {
    final rounded = (detection.distanceMeters / 50).round() * 50;
    return rounded < 50 ? 'arriving now' : 'about $rounded m away';
  }

  String get instruction =>
      'Move to the right side and stop, clear of the intersection.';

  String get notificationTitle => 'Emergency vehicle approaching';

  String get notificationBody =>
      '${detection.vehicleType.label} from the ${lane.label} at $intersectionName. $instruction';

  Map<String, dynamic> toJson() => {
        'intersectionId': intersectionId,
        'intersectionName': intersectionName,
        ...detection.toJson(),
        'headline': headline,
        'distanceLabel': distanceLabel,
        'instruction': instruction,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
      };
}

/// A full snapshot of one intersection for one second. This is what will be
/// published to Supabase and drawn by the app.
class IntersectionFrame {
  const IntersectionFrame({
    required this.intersectionId,
    required this.name,
    required this.time,
    required this.mode,
    required this.lanes,
    required this.crosswalks,
    required this.perceive,
    required this.decide,
    required this.act,
    required this.vehiclesToday,
    required this.emergencyAlertsToday,
    required this.events,
    this.emergency,
  });

  final int intersectionId;
  final String name;
  final DateTime time;
  final IntersectionMode mode;

  /// Always in the order north, south, east, west.
  final List<LaneStatus> lanes;
  final Map<Lane, CrosswalkState> crosswalks;

  /// The three lines of the "Intelligent Agent" card.
  final String perceive;
  final String decide;
  final String act;

  final int vehiclesToday;
  final int emergencyAlertsToday;

  /// Events created during this tick only.
  final List<TrafficEvent> events;

  /// Set while an emergency vehicle is approaching.
  final EmergencyAlert? emergency;

  Map<String, dynamic> toJson() => {
        'intersectionId': intersectionId,
        'name': name,
        'time': time.toUtc().toIso8601String(),
        'mode': mode.name,
        'modeLabel': mode.label,
        'lanes': [for (final l in lanes) l.toJson()],
        'crosswalks': {
          for (final e in crosswalks.entries) e.key.name: e.value.name,
        },
        'perceive': perceive,
        'decide': decide,
        'act': act,
        'vehiclesToday': vehiclesToday,
        'emergencyAlertsToday': emergencyAlertsToday,
        'emergency': emergency?.toJson(),
        'events': [for (final e in events) e.toJson()],
      };
}
