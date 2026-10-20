import 'dart:async';
import 'dart:io';

import 'package:radiant_core/radiant_core.dart';
import 'package:radiant_simulator/env.dart';
import 'package:radiant_simulator/payloads.dart';
import 'package:radiant_simulator/supabase_rest.dart';

/// Runs the traffic simulation in real time (one tick per second) and
/// publishes every tick to Supabase, so every phone sees the same state.
///
///   dart run bin/run.dart                 run until Ctrl+C
///   dart run bin/run.dart --seconds 120   run for two minutes
///   dart run bin/run.dart --seed 7        different random traffic
///   dart run bin/run.dart --warmup 0      skip the 90 s silent warm-up
///   dart run bin/run.dart --emergency-boost 10   many more emergency vehicles (demos)
///   dart run bin/run.dart --replay replay/sample_detections.jsonl --replay-intersection 1
///
/// Each start wipes old events and active emergencies so the demo starts clean.
Future<void> main(List<String> args) async {
  final env = loadEnv();
  final url = env['SUPABASE_URL'] ?? '';
  final key = env['SUPABASE_SERVICE_KEY'] ?? '';
  if (url.isEmpty || key.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY.');
    stderr.writeln('Copy .env.example to .env in this folder and fill it in.');
    exit(64);
  }

  final seed = _intArg(args, '--seed', 42);
  final seconds = _intArg(args, '--seconds', 0); // 0 means until Ctrl+C
  final warmup = _intArg(args, '--warmup', 90); // silent warm-up, 0 to skip
  final boost = _doubleArg(args, '--emergency-boost', 1.0);

  final db = SupabaseRest(url: url, key: key);
  // Optional: drive one intersection from recorded detector output.
  List<IntersectionSource>? sources;
  final replayPath = _stringArg(args, '--replay');
  if (replayPath != null) {
    final replayId = _intArg(args, '--replay-intersection', 1);
    final file = File(replayPath);
    if (!file.existsSync()) {
      stderr.writeln('Replay file not found: $replayPath');
      exit(64);
    }
    final frames = ReplayFrame.parseJsonLines(file.readAsStringSync());
    if (frames.isEmpty) {
      stderr.writeln('The replay file has no frames: $replayPath');
      exit(64);
    }
    sources = <IntersectionSource>[
      ...TrafficSimulator.defaultIntersections(seed, emergencyBoost: boost),
    ];
    final index = sources.indexWhere((s) => s.id == replayId);
    if (index == -1) {
      stderr.writeln('There is no intersection $replayId to replay onto.');
      exit(64);
    }
    sources[index] = ReplayIntersection(
      id: replayId,
      name: sources[index].name,
      frames: frames,
    );
    stdout.writeln(
      'Intersection $replayId replays ${frames.length} s of detections '
      'from $replayPath.',
    );
  }

  final sim = TrafficSimulator(
    seed: seed,
    emergencyBoost: boost,
    intersections: sources,
    start: DateTime.now().toUtc().subtract(Duration(seconds: warmup + 1)),
  );

  var stopping = false;
  ProcessSignal.sigint.watch().listen((_) {
    if (stopping) exit(130);
    stopping = true;
    stdout.writeln('\nStopping after this tick (press Ctrl+C again to force)...');
  });

  try {
    await db.delete('events', 'id=gt.0');
    await db.delete('active_emergencies', 'intersection_id=gt.0');
  } catch (e) {
    stderr.writeln('Could not reach Supabase: $e');
    stderr.writeln('Check SUPABASE_URL and SUPABASE_SERVICE_KEY, and that '
        'supabase/schema.sql has been run.');
    exit(1);
  }

  if (warmup > 0) {
    stdout.writeln('Warming up for $warmup simulated seconds (nothing is published)...');
    for (var i = 0; i < warmup; i++) {
      sim.tick();
    }
    // Alerts that happened during warm-up have no events in the log.
    for (final i in sim.intersections) {
      i.emergencyAlertsToday = 0;
    }
  }

  stdout.writeln('Radiant simulator publishing to $url (seed $seed).');
  stdout.writeln(seconds == 0
      ? 'Press Ctrl+C to stop.'
      : 'Running for $seconds seconds.');

  var tick = 0;
  var failures = 0;
  var activeEmergencies = <int>{};
  final lastMode = <int, String>{};
  final lastAlerts = <int, int>{};

  while (!stopping && (seconds == 0 || tick < seconds)) {
    final timer = Stopwatch()..start();
    final frames = sim.tick();
    final now = DateTime.now().toUtc();

    try {
      // Summary cards change slowly, so send them on change and every 5 s.
      final summaryChanged = tick % 5 == 0 ||
          frames.any((f) =>
              lastMode[f.intersectionId] != f.mode.name ||
              lastAlerts[f.intersectionId] != f.emergencyAlertsToday);
      if (summaryChanged) {
        await db.upsert('intersections', intersectionRows(frames, now),
            onConflict: 'id');
        for (final f in frames) {
          lastMode[f.intersectionId] = f.mode.name;
          lastAlerts[f.intersectionId] = f.emergencyAlertsToday;
        }
      }

      await db.upsert('intersection_live', liveRows(frames, now),
          onConflict: 'intersection_id');

      await db.insert('events', eventRows(frames));

      await db.upsert('active_emergencies', emergencyRows(frames, now),
          onConflict: 'intersection_id');

      final current = {
        for (final f in frames)
          if (f.emergency != null) f.intersectionId,
      };
      final ended = activeEmergencies.difference(current);
      if (ended.isNotEmpty) {
        await db.delete(
            'active_emergencies', 'intersection_id=in.(${ended.join(',')})');
      }
      activeEmergencies = current;

      for (final f in frames) {
        for (final e in f.events) {
          stdout.writeln(
              '${f.name}: [${e.type.label}] ${e.laneLabel}: ${e.description}');
        }
      }
      if (failures > 0) {
        stdout.writeln('Connection recovered.');
        failures = 0;
      }
      if (tick % 30 == 0) stdout.writeln('${_clock()}  tick $tick ok');
    } catch (e) {
      failures++;
      stderr.writeln('${_clock()}  tick $tick failed ($failures in a row): $e');
      if (failures >= 5) await Future<void>.delayed(const Duration(seconds: 5));
    }

    tick++;
    final wait = 1000 - timer.elapsedMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
  }

  try {
    await db.delete('active_emergencies', 'intersection_id=gt.0');
  } catch (_) {
    // Best effort: leave nothing stale behind for the apps.
  }
  db.close();
  stdout.writeln('Stopped after $tick ticks.');
}

double _doubleArg(List<String> args, String name, double fallback) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return fallback;
  return double.tryParse(args[i + 1]) ?? fallback;
}

String? _stringArg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _clock() => DateTime.now().toIso8601String().substring(11, 19);
