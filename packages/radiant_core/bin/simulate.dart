import 'dart:io';

import 'package:radiant_core/radiant_core.dart';

/// Command-line runner for the agent and simulator.
///
///   dart run bin/simulate.dart                         (120 s, intersection 3)
///   dart run bin/simulate.dart --intersection 4        (the empty road)
///   dart run bin/simulate.dart --seconds 600 --seed 7
///   dart run bin/simulate.dart --explain               (PERCEIVE/DECIDE/ACT every second)
///   dart run bin/simulate.dart --realtime              (one tick per real second)
Future<void> main(List<String> args) async {
  final seconds = _intArg(args, '--seconds', 120);
  final seed = _intArg(args, '--seed', 42);
  final focus = _intArg(args, '--intersection', 3);
  final explain = args.contains('--explain');
  final realtime = args.contains('--realtime');

  final sim = TrafficSimulator(seed: seed);
  IntersectionFrame? last;

  stdout.writeln('Radiant simulation: intersection $focus, $seconds s, seed $seed');
  stdout.writeln('');

  for (var i = 0; i < seconds; i++) {
    final frames = sim.tick();
    final frame = frames.firstWhere(
      (f) => f.intersectionId == focus,
      orElse: () => frames.first,
    );
    last = frame;

    stdout.writeln(_line(frame));
    for (final e in frame.events) {
      stdout.writeln('    >> [${e.type.label}] ${e.laneLabel}: ${e.description}');
    }
    if (explain) {
      stdout.writeln('       PERCEIVE: ${frame.perceive}');
      stdout.writeln('       DECIDE:   ${frame.decide}');
      stdout.writeln('       ACT:      ${frame.act}');
    }
    if (realtime) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  stdout.writeln('');
  stdout.writeln('--- Totals after $seconds s ---');
  for (final i in sim.intersections) {
    stdout.writeln(
      '${i.name}: ${i.vehiclesToday} vehicles passed, '
      '${i.emergencyAlertsToday} emergency alerts',
    );
  }
  if (last != null) {
    stdout.writeln('');
    stdout.writeln('Last agent state for ${last.name}:');
    stdout.writeln('  PERCEIVE: ${last.perceive}');
    stdout.writeln('  DECIDE:   ${last.decide}');
    stdout.writeln('  ACT:      ${last.act}');
  }
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _line(IntersectionFrame f) {
  final time = f.time.toIso8601String().substring(11, 19);
  final lanes = f.lanes
      .map((l) => '${l.lane.initial}:${l.vehicleCount.toString().padLeft(2)} ${_signal(l)}')
      .join(' | ');
  return '$time  ${f.mode.name.padRight(9)} $lanes';
}

String _signal(LaneStatus l) {
  final text = switch (l.signal) {
    SignalState.go => 'GO(${l.secondsRemaining ?? '-'}s)',
    SignalState.yellow => 'YEL(${l.secondsRemaining ?? '-'}s)',
    SignalState.stop => 'STOP',
    SignalState.flashYellow => 'FLASH',
  };
  return text.padRight(8);
}
