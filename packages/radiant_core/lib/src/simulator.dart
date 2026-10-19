import 'dart:math' as math;

import 'models.dart';
import 'traffic_agent.dart';

/// How busy one intersection is.
class IntersectionProfile {
  const IntersectionProfile({
    required this.vehiclesPerSecond,
    this.pedestriansPerSecond = 0,
    this.emergenciesPerHour = 0,
  });

  /// Chance (0 to 1) that one vehicle arrives in a lane each second.
  final Map<Lane, double> vehiclesPerSecond;

  /// Chance (0 to 1) that a pedestrian starts waiting at each crosswalk.
  final double pedestriansPerSecond;

  /// Average emergency vehicles per hour. Zero means none.
  final double emergenciesPerHour;
}

/// World rules for the simulation.
class SimulationConfig {
  const SimulationConfig({
    this.laneCapacity = 25,
    this.goDeparturesPerSecond = 0.7,
    this.yellowDeparturesPerSecond = 0.45,
    this.flashDeparturesPerSecond = 0.35,
    this.pedestriansCrossingPerSecond = 2,
    this.emergencyStartDistanceMeters = 450,
    this.emergencySpeedMetersPerSecond = 15,
  });

  final int laneCapacity;
  final double goDeparturesPerSecond;
  final double yellowDeparturesPerSecond;
  final double flashDeparturesPerSecond;
  final int pedestriansCrossingPerSecond;
  final double emergencyStartDistanceMeters;
  final double emergencySpeedMetersPerSecond;
}

/// Simulates the camera and vehicle classifier for one intersection and feeds
/// the result to a [TrafficAgent]. The agent only ever sees a [Percept], so a
/// real detector could replace this class later.
class IntersectionSimulator {
  IntersectionSimulator({
    required this.id,
    required this.name,
    required this.profile,
    int seed = 0,
    this.sim = const SimulationConfig(),
    AgentConfig agentConfig = const AgentConfig(),
  })  : _random = math.Random(seed + id),
        agent = TrafficAgent(intersectionId: id, config: agentConfig);

  final int id;
  final String name;
  final IntersectionProfile profile;
  final SimulationConfig sim;
  final TrafficAgent agent;
  final math.Random _random;

  final Map<Lane, int> _queues = {for (final l in Lane.values) l: 0};
  final Map<Lane, int> _pedestrians = {for (final l in Lane.values) l: 0};
  final Map<Lane, double> _credit = {for (final l in Lane.values) l: 0.0};
  EmergencyDetection? _emergency;

  int vehiclesToday = 0;
  int emergencyAlertsToday = 0;

  /// Runs one simulated second.
  IntersectionFrame step(DateTime now) {
    _updateEmergency();
    _arrivals();

    final counts = {
      for (final l in Lane.values)
        l: _queues[l]! + (_emergency?.lane == l ? 1 : 0),
    };
    final percept = Percept(
      intersectionId: id,
      vehicleCounts: counts,
      pedestriansWaiting: Map<Lane, int>.of(_pedestrians),
      emergency: _emergency,
    );

    final decision = agent.step(percept, now);
    _applyDecision(decision);

    for (final event in decision.events) {
      if (event.type == EventType.emergencyDetected) emergencyAlertsToday++;
    }

    final emergency = _emergency;
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
      emergency: emergency == null
          ? null
          : EmergencyAlert(
              intersectionId: id,
              intersectionName: name,
              detection: emergency,
            ),
    );
  }

  void _updateEmergency() {
    final current = _emergency;
    if (current != null) {
      final next = current.distanceMeters - sim.emergencySpeedMetersPerSecond;
      _emergency = next <= 0 ? null : current.withDistance(next);
      return;
    }
    if (profile.emergenciesPerHour > 0 &&
        _random.nextDouble() < profile.emergenciesPerHour / 3600) {
      _emergency = EmergencyDetection(
        lane: Lane.values[_random.nextInt(Lane.values.length)],
        vehicleType: _random.nextDouble() < 0.7
            ? EmergencyVehicleType.ambulance
            : EmergencyVehicleType.fireTruck,
        confidence: 0.90 + _random.nextDouble() * 0.09,
        distanceMeters: sim.emergencyStartDistanceMeters,
      );
    }
  }

  void _arrivals() {
    for (final lane in Lane.values) {
      final chance = profile.vehiclesPerSecond[lane] ?? 0;
      if (chance > 0 &&
          _queues[lane]! < sim.laneCapacity &&
          _random.nextDouble() < chance) {
        _queues[lane] = _queues[lane]! + 1;
      }
      if (profile.pedestriansPerSecond > 0 &&
          _pedestrians[lane]! < 6 &&
          _random.nextDouble() < profile.pedestriansPerSecond) {
        _pedestrians[lane] = _pedestrians[lane]! + 1;
      }
    }
  }

  void _applyDecision(AgentDecision decision) {
    for (final lane in Lane.values) {
      if (decision.crosswalks[lane] != CrosswalkState.dontWalk) {
        _pedestrians[lane] =
            math.max(0, _pedestrians[lane]! - sim.pedestriansCrossingPerSecond);
      }

      final rate = switch (decision.lanes[lane]!.signal) {
        SignalState.go => sim.goDeparturesPerSecond,
        SignalState.yellow => sim.yellowDeparturesPerSecond,
        SignalState.flashYellow => sim.flashDeparturesPerSecond,
        SignalState.stop => 0.0,
      };
      if (rate == 0.0) {
        _credit[lane] = 0.0;
        continue;
      }

      final credit = _credit[lane]! + rate;
      var leaving = credit.floor();
      if (leaving > _queues[lane]!) leaving = _queues[lane]!;
      _credit[lane] = credit - credit.floor();
      _queues[lane] = _queues[lane]! - leaving;
      vehiclesToday += leaving;
    }
  }
}

/// Runs all intersections on one shared simulated clock.
class TrafficSimulator {
  TrafficSimulator({
    int seed = 42,
    DateTime? start,
    List<IntersectionSimulator>? intersections,
    this.maxEvents = 500,
  })  : _time = start ?? DateTime.utc(2026, 10, 19, 8),
        intersections = intersections ?? defaultIntersections(seed);

  final List<IntersectionSimulator> intersections;
  final int maxEvents;

  DateTime _time;
  final List<TrafficEvent> _events = [];

  DateTime get time => _time;

  /// Newest first, capped at [maxEvents].
  List<TrafficEvent> get events => List.unmodifiable(_events);

  /// Advances the clock one second and returns a frame per intersection.
  List<IntersectionFrame> tick() {
    _time = _time.add(const Duration(seconds: 1));
    final frames = [for (final i in intersections) i.step(_time)];
    for (final frame in frames) {
      for (final event in frame.events) {
        _events.insert(0, event);
      }
    }
    if (_events.length > maxEvents) {
      _events.removeRange(maxEvents, _events.length);
    }
    return frames;
  }

  /// Intersections 01 to 05 as in the design:
  /// 01 busy east-west, 02 busy north-south, 03 balanced with the most
  /// emergencies, 04 an empty road, 05 normal traffic with pedestrians.
  static List<IntersectionSimulator> defaultIntersections(int seed) {
    IntersectionProfile profile(
      double n,
      double s,
      double e,
      double w, {
      double pedestrians = 0,
      double emergencies = 0,
    }) =>
        IntersectionProfile(
          vehiclesPerSecond: {
            Lane.north: n,
            Lane.south: s,
            Lane.east: e,
            Lane.west: w,
          },
          pedestriansPerSecond: pedestrians,
          emergenciesPerHour: emergencies,
        );

    final profiles = [
      profile(0.09, 0.07, 0.14, 0.11, emergencies: 12),
      profile(0.12, 0.10, 0.06, 0.05, emergencies: 12),
      profile(0.08, 0.08, 0.07, 0.07, emergencies: 20),
      profile(0, 0, 0, 0),
      profile(0.06, 0.06, 0.06, 0.06, pedestrians: 0.08, emergencies: 8),
    ];

    return [
      for (var i = 0; i < profiles.length; i++)
        IntersectionSimulator(
          id: i + 1,
          name: 'Intersection ${(i + 1).toString().padLeft(2, '0')}',
          profile: profiles[i],
          seed: seed,
        ),
    ];
  }
}
