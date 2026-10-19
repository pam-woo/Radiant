import 'dart:math' as math;

import 'models.dart';

/// Tunable numbers for the agent. Defaults follow the Radiant design:
/// 5 s minimum green and 3 s yellow.
class AgentConfig {
  const AgentConfig({
    this.minGreenSeconds = 5,
    this.yellowSeconds = 3,
    this.maxGreenSeconds = 40,
    this.extendStepSeconds = 6,
    this.maxRedWaitSeconds = 60,
    this.secondsPerVehicle = 1.0,
    this.idleAfterEmptySeconds = 5,
    this.walkClearanceSeconds = 4,
  });

  /// A green is never cut shorter than this.
  final int minGreenSeconds;

  /// Every green is followed by exactly this much yellow.
  final int yellowSeconds;

  /// A green never lasts longer than this while another direction is waiting.
  final int maxGreenSeconds;

  /// How much a green is extended each time the agent decides to extend it.
  final int extendStepSeconds;

  /// If the waiting direction has waited this long, it gets the next green.
  final int maxRedWaitSeconds;

  /// Planned green = minGreen + vehicles on the axis * this value.
  final double secondsPerVehicle;

  /// The intersection goes idle after being empty for this long.
  final int idleAfterEmptySeconds;

  /// Pedestrians are not sent across in the last seconds of a planned green.
  final int walkClearanceSeconds;
}

/// The agent's output for one tick.
class AgentDecision {
  const AgentDecision({
    required this.mode,
    required this.lanes,
    required this.crosswalks,
    required this.perceive,
    required this.decide,
    required this.act,
    required this.events,
  });

  final IntersectionMode mode;
  final Map<Lane, LaneStatus> lanes;
  final Map<Lane, CrosswalkState> crosswalks;
  final String perceive;
  final String decide;
  final String act;
  final List<TrafficEvent> events;
}

enum _Phase { green, yellow }

typedef _Logger = void Function(EventType type, String laneLabel, String text);

/// A model-based, rule- and priority-based traffic signal agent.
///
/// It remembers its own state (current phase, how long it has lasted, how
/// long each direction has waited) and, once per second, turns a [Percept]
/// into signal states plus a PERCEIVE / DECIDE / ACT explanation.
///
/// Rules, in short:
///  * Lane density decides who gets green, with a minimum green and a fixed
///    yellow. A busier waiting direction takes over; a busier green direction
///    is extended, up to a maximum, so nobody starves.
///  * An emergency vehicle changes no timing. The busiest (green) lanes just
///    flash yellow as a warning and drivers are alerted.
///  * An empty intersection flashes yellow and pedestrians cross freely.
class TrafficAgent {
  TrafficAgent({required this.intersectionId, this.config = const AgentConfig()});

  final int intersectionId;
  final AgentConfig config;

  bool _started = false;
  bool _idle = false;
  bool _emergencyActive = false;
  bool _holding = false;
  Axis _greenAxis = Axis.northSouth;
  _Phase _phase = _Phase.green;

  // Number of frames shown in the current phase, counting the current one.
  int _phaseElapsed = 0;
  int _plannedGreen = 0;
  int _emptySeconds = 0;
  final Map<Axis, int> _redWait = {Axis.northSouth: 0, Axis.eastWest: 0};
  final Map<Axis, bool> _walkActive = {
    Axis.northSouth: false,
    Axis.eastWest: false,
  };

  /// Advances the agent by exactly one second.
  AgentDecision step(Percept percept, DateTime now) {
    final events = <TrafficEvent>[];

    void log(EventType type, String laneLabel, String text) {
      events.add(TrafficEvent(
        time: now,
        intersectionId: intersectionId,
        laneLabel: laneLabel,
        type: type,
        description: text,
      ));
    }

    final ns = percept.axisDensity(Axis.northSouth);
    final ew = percept.axisDensity(Axis.eastWest);
    final total = ns + ew;
    final emergency = percept.emergency;

    _emptySeconds = total == 0 ? _emptySeconds + 1 : 0;
    var phaseJustStarted = false;

    if (!_started) {
      _started = true;
      phaseJustStarted = true;
      _startGreen(_busierAxis(ns, ew), percept);
    }

    // Only go idle between phases, never in the middle of a yellow.
    final canEnterIdle = emergency == null &&
        _emptySeconds >= config.idleAfterEmptySeconds &&
        _phase == _Phase.green;

    if (!_idle && canEnterIdle) {
      _idle = true;
      log(EventType.idleMode, 'All',
          'No vehicles: flashing yellow, pedestrians cross');
    } else if (_idle && total > 0) {
      _idle = false;
      phaseJustStarted = true;
      // Cars that were flashing yellow cannot jump straight to red, so the
      // direction that will wait gets a yellow first.
      _greenAxis = _busierAxis(ns, ew).other;
      _phase = _Phase.yellow;
      _phaseElapsed = 1;
      _holding = false;
      _redWait.updateAll((axis, value) => 0);
      log(EventType.densityAdjust, 'All',
          'Vehicles detected: normal cycle resumed');
    }

    if (!_idle && !phaseJustStarted) {
      _advance(percept, log);
    }

    if (emergency != null && !_emergencyActive) {
      log(EventType.emergencyDetected, emergency.lane.label,
          'Flashing yellow, drivers alerted');
    } else if (emergency == null && _emergencyActive) {
      log(EventType.densityAdjust, 'All',
          'Emergency vehicle passed: normal cycle resumed');
    }
    _emergencyActive = emergency != null;

    final mode = _idle
        ? IntersectionMode.idle
        : (emergency != null
            ? IntersectionMode.emergency
            : IntersectionMode.normal);

    final signals = _signals(mode);
    final crosswalks = _crosswalks(percept, signals);

    for (final axis in Axis.values) {
      final walking =
          axis.lanes.any((l) => crosswalks[l] == CrosswalkState.walk);
      if (walking && !_walkActive[axis]!) {
        log(EventType.pedestrianCrossing, axis.laneLabels,
            'Walk signal on ${axis.label} while traffic is stopped');
      }
      _walkActive[axis] = walking;
    }

    final lanes = {
      for (final lane in Lane.values)
        lane: LaneStatus(
          lane: lane,
          vehicleCount: percept.count(lane),
          signal: signals[lane]!,
          secondsRemaining: _secondsRemaining(signals[lane]!),
        ),
    };

    return AgentDecision(
      mode: mode,
      lanes: lanes,
      crosswalks: crosswalks,
      perceive: _perceiveText(percept),
      decide: _decideText(percept, mode),
      act: _actText(mode),
      events: List.unmodifiable(events),
    );
  }

  // ---- phase logic -------------------------------------------------------

  Axis _busierAxis(int ns, int ew) {
    if (ew > ns) return Axis.eastWest;
    if (ns > ew) return Axis.northSouth;
    return _greenAxis;
  }

  int _planGreen(int density) {
    final planned =
        (config.minGreenSeconds + density * config.secondsPerVehicle).round();
    return math.max(config.minGreenSeconds,
        math.min(config.maxGreenSeconds, planned));
  }

  void _startGreen(Axis axis, Percept percept) {
    _greenAxis = axis;
    _phase = _Phase.green;
    _phaseElapsed = 1;
    _holding = false;
    _redWait[axis] = 0;
    _plannedGreen = _planGreen(percept.axisDensity(axis));
  }

  void _beginYellow(Axis waiting, String? reason, _Logger log) {
    _phase = _Phase.yellow;
    _phaseElapsed = 1;
    _holding = false;
    final base = 'Switched phase to ${waiting.label}';
    log(EventType.densityAdjust, _greenAxis.laneLabels,
        reason == null ? base : '$base: $reason');
  }

  void _advance(Percept percept, _Logger log) {
    final waiting = _greenAxis.other;
    _redWait[waiting] = _redWait[waiting]! + 1;
    _phaseElapsed++;

    if (_phase == _Phase.yellow) {
      if (_phaseElapsed > config.yellowSeconds) {
        final finished = _greenAxis;
        _startGreen(waiting, percept);
        _redWait[finished] = 0;
      }
      return;
    }

    _holding = false;

    // Green frames already shown, not counting the current one.
    final shown = _phaseElapsed - 1;
    if (shown < config.minGreenSeconds) return;

    final greenDensity = percept.axisDensity(_greenAxis);
    final waitingDensity = percept.axisDensity(waiting);

    // Nobody left on the green direction, someone is waiting: hand over now.
    if (greenDensity == 0 && waitingDensity > 0) {
      _beginYellow(waiting, 'no vehicles left on ${_greenAxis.label}', log);
      return;
    }

    if (shown < _plannedGreen) return;

    final pedestriansAtGreen = percept.pedestriansOn(_greenAxis);
    if (waitingDensity == 0 && pedestriansAtGreen == 0) {
      _holding = true;
      return;
    }
    if (waitingDensity == 0) {
      _beginYellow(waiting, 'pedestrians waiting', log);
      return;
    }

    final waitedTooLong = _redWait[waiting]! >= config.maxRedWaitSeconds;
    final base = math.max(_plannedGreen, shown);
    final room = config.maxGreenSeconds - base;
    if (!waitedTooLong && greenDensity > waitingDensity && room > 0) {
      final extra = math.min(config.extendStepSeconds, room);
      _plannedGreen = base + extra;
      log(EventType.densityAdjust, _greenAxis.laneLabels,
          'Extended ${_greenAxis.label} green by $extra s');
      return;
    }

    _beginYellow(waiting, null, log);
  }

  // ---- outputs -----------------------------------------------------------

  Map<Lane, SignalState> _signals(IntersectionMode mode) {
    return {
      for (final lane in Lane.values)
        lane: mode == IntersectionMode.idle
            ? SignalState.flashYellow
            : lane.axis != _greenAxis
                ? SignalState.stop
                : _phase == _Phase.yellow
                    ? SignalState.yellow
                    : (mode == IntersectionMode.emergency
                        ? SignalState.flashYellow
                        : SignalState.go),
    };
  }

  int? _secondsRemaining(SignalState signal) {
    return switch (signal) {
      SignalState.go => _holding
          ? null
          : math.max(0, _plannedGreen - _phaseElapsed + 1),
      SignalState.yellow =>
        math.max(0, config.yellowSeconds - _phaseElapsed + 1),
      SignalState.stop || SignalState.flashYellow => null,
    };
  }

  Map<Lane, CrosswalkState> _crosswalks(
      Percept percept, Map<Lane, SignalState> signals) {
    if (_idle) {
      return {for (final l in Lane.values) l: CrosswalkState.free};
    }
    final remaining = _plannedGreen - _phaseElapsed + 1;
    final safeToWalk = _phase == _Phase.green &&
        (_holding || remaining > config.walkClearanceSeconds);
    return {
      for (final l in Lane.values)
        l: (signals[l] == SignalState.stop &&
                percept.pedestriansWaiting[l]! > 0 &&
                safeToWalk)
            ? CrosswalkState.walk
            : CrosswalkState.dontWalk,
    };
  }

  String _perceiveText(Percept percept) {
    final counts =
        Lane.values.map((l) => '${l.initial}${percept.count(l)}').join(' ');
    final e = percept.emergency;
    if (e == null) return '$counts. No emergency vehicle.';
    final pct = (e.confidence * 100).round();
    return '${e.vehicleType.label} in the ${e.lane.label} lane ($pct%). $counts.';
  }

  String _decideText(Percept percept, IntersectionMode mode) {
    switch (mode) {
      case IntersectionMode.idle:
        return 'No vehicles detected. Cars get flashing yellow and pedestrians may cross.';
      case IntersectionMode.emergency:
        return 'Emergency vehicle approaching. The busiest lanes flash yellow as a warning; other signals keep following lane density.';
      case IntersectionMode.normal:
        break;
    }
    final other = _greenAxis.other;
    final g = percept.axisDensity(_greenAxis);
    final o = percept.axisDensity(other);
    if (_phase == _Phase.yellow) {
      return 'Clearing ${_greenAxis.label} before ${other.label} gets its green.';
    }
    if (_holding) {
      return '${_greenAxis.label} keeps its green because nothing is waiting on ${other.label}.';
    }
    if (g > o) {
      return '${_greenAxis.label} is busier ($g vs $o vehicles), so it keeps the green.';
    }
    if (o > g) {
      return '${other.label} is busier ($o vs $g vehicles), so it goes next.';
    }
    return 'Both directions are equally busy ($g vehicles each).';
  }

  String _actText(IntersectionMode mode) {
    final other = _greenAxis.other;
    switch (mode) {
      case IntersectionMode.idle:
        return 'Flashing yellow on every approach until vehicles arrive.';
      case IntersectionMode.emergency:
        if (_phase == _Phase.yellow) {
          return 'Clearing ${_greenAxis.label} with yellow; flashing yellow returns on the busiest lanes. Drivers alerted.';
        }
        return 'Flashing yellow on the busiest lanes until the vehicle has passed. Drivers alerted.';
      case IntersectionMode.normal:
        break;
    }
    if (_phase == _Phase.yellow) {
      final left = math.max(0, config.yellowSeconds - _phaseElapsed + 1);
      return '${_greenAxis.label} yellow for $left s, then ${other.label} green.';
    }
    if (_holding) {
      return '${_greenAxis.label} green held until a vehicle or pedestrian is waiting.';
    }
    return '${_greenAxis.label} green for $_plannedGreen s, then ${config.yellowSeconds} s yellow, then ${other.label}.';
  }
}
