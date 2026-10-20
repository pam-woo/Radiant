import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Streams the simulation from Supabase and keeps the latest copy on the
/// device, so screens still show something when the connection drops.
class RadiantRepository extends ChangeNotifier {
  RadiantRepository(this._client, this._prefs) {
    _loadCache();
  }

  static const _staleAfter = Duration(seconds: 12);
  static const _kLive = 'cache_live';
  static const _kSummaries = 'cache_summaries';
  static const _kEvents = 'cache_events';

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  final Map<int, IntersectionSummary> _summaries = {};
  final Map<int, LiveFrame> _live = {};
  List<EventItem> _events = [];
  List<ActiveEmergency> _emergencies = [];

  List<Map<String, dynamic>> _rawLive = [];
  List<Map<String, dynamic>> _rawSummaries = [];
  List<Map<String, dynamic>> _rawEvents = [];

  StreamSubscription<List<Map<String, dynamic>>>? _liveSub;
  StreamSubscription<List<Map<String, dynamic>>>? _summarySub;
  StreamSubscription<List<Map<String, dynamic>>>? _eventSub;
  StreamSubscription<List<Map<String, dynamic>>>? _emergencySub;
  Timer? _timer;

  DateTime _startedAt = DateTime.now();
  DateTime? _lastDataAt;
  bool _streamError = false;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  // ---- reading -----------------------------------------------------------

  /// True when no fresh data has arrived recently (or a stream failed). The
  /// screens then show the last saved data with a banner.
  bool get offline {
    if (_streamError) return true;
    final last = _lastDataAt ?? _startedAt;
    return DateTime.now().difference(last) > _staleAfter;
  }

  List<IntersectionSummary> get summaries {
    final list = _summaries.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  IntersectionSummary? summaryFor(int id) => _summaries[id];

  LiveFrame? liveFor(int id) => _live[id];

  List<EventItem> eventsFor(int? intersectionId, {int limit = 100}) {
    final Iterable<EventItem> source = intersectionId == null
        ? _events
        : _events.where((e) => e.intersectionId == intersectionId);
    return source.take(limit).toList();
  }

  List<ActiveEmergency> get activeEmergencies =>
      List.unmodifiable(_emergencies);

  /// The closest approaching emergency vehicle, if any.
  ActiveEmergency? get nearestEmergency =>
      _emergencies.isEmpty ? null : _emergencies.first;

  ActiveEmergency? emergencyFor(int intersectionId) {
    for (final e in _emergencies) {
      if (e.intersectionId == intersectionId) return e;
    }
    return null;
  }

  // ---- streaming ---------------------------------------------------------

  /// Starts listening. Drivers pass includeLive: false because the live
  /// lane data is admin only.
  void start({required bool includeLive}) {
    stop();
    _startedAt = DateTime.now();
    _lastDataAt = null;
    _streamError = false;

    _summarySub = _client
        .from('intersections')
        .stream(primaryKey: ['id']).listen((rows) {
      _rawSummaries = rows;
      _applySummaries(rows);
      _touch();
    }, onError: _onError);

    if (includeLive) {
      _liveSub = _client
          .from('intersection_live')
          .stream(primaryKey: ['intersection_id']).listen((rows) {
        _rawLive = rows;
        _applyLive(rows);
        _touch();
      }, onError: _onError);
    }

    _eventSub = _client
        .from('events')
        .stream(primaryKey: ['id'])
        .order('occurred_at', ascending: false)
        .limit(200)
        .listen((rows) {
      _rawEvents = rows;
      _applyEvents(rows);
      _touch();
    }, onError: _onError);

    _emergencySub = _client
        .from('active_emergencies')
        .stream(primaryKey: ['intersection_id']).listen((rows) {
      _applyEmergencies(rows);
      _touch();
    }, onError: _onError);

    // Re-check staleness every couple of seconds.
    _timer =
        Timer.periodic(const Duration(seconds: 2), (_) => notifyListeners());
  }

  void stop() {
    _liveSub?.cancel();
    _summarySub?.cancel();
    _eventSub?.cancel();
    _emergencySub?.cancel();
    _timer?.cancel();
    _liveSub = null;
    _summarySub = null;
    _eventSub = null;
    _emergencySub = null;
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _onError(Object error) {
    _streamError = true;
    notifyListeners();
  }

  void _touch() {
    _lastDataAt = DateTime.now();
    _streamError = false;
    _saveCache();
    notifyListeners();
  }

  // ---- parsing -----------------------------------------------------------

  void _applySummaries(List<Map<String, dynamic>> rows) {
    _summaries.clear();
    for (final row in rows) {
      try {
        final s = IntersectionSummary.fromRow(row);
        _summaries[s.id] = s;
      } catch (_) {
        // Skip a row that does not match the expected shape.
      }
    }
  }

  void _applyLive(List<Map<String, dynamic>> rows) {
    _live.clear();
    for (final row in rows) {
      try {
        final frame = row['frame'];
        if (frame is Map) {
          final f = LiveFrame.fromJson(Map<String, dynamic>.from(frame));
          _live[f.intersectionId] = f;
        }
      } catch (_) {
        // Skip a row that does not match the expected shape.
      }
    }
  }

  void _applyEvents(List<Map<String, dynamic>> rows) {
    final parsed = <EventItem>[];
    for (final row in rows) {
      try {
        parsed.add(EventItem.fromRow(row));
      } catch (_) {
        // Skip a row that does not match the expected shape.
      }
    }
    parsed.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    _events = parsed;
  }

  void _applyEmergencies(List<Map<String, dynamic>> rows) {
    final parsed = <ActiveEmergency>[];
    for (final row in rows) {
      try {
        parsed.add(ActiveEmergency.fromRow(row));
      } catch (_) {
        // Skip a row that does not match the expected shape.
      }
    }
    parsed.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    _emergencies = parsed;
  }

  // ---- device cache ------------------------------------------------------

  void _saveCache() {
    final now = DateTime.now();
    if (now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    try {
      _prefs.setString(_kLive, jsonEncode(_rawLive));
      _prefs.setString(_kSummaries, jsonEncode(_rawSummaries));
      _prefs.setString(_kEvents, jsonEncode(_rawEvents));
    } catch (_) {
      // The cache is a convenience, never a reason to fail.
    }
  }

  void _loadCache() {
    try {
      final live = _prefs.getString(_kLive);
      if (live != null) {
        _rawLive = _decodeRows(live);
        _applyLive(_rawLive);
      }
      final summaries = _prefs.getString(_kSummaries);
      if (summaries != null) {
        _rawSummaries = _decodeRows(summaries);
        _applySummaries(_rawSummaries);
      }
      final events = _prefs.getString(_kEvents);
      if (events != null) {
        _rawEvents = _decodeRows(events);
        _applyEvents(_rawEvents);
      }
    } catch (_) {
      // Ignore a damaged cache.
    }
  }

  List<Map<String, dynamic>> _decodeRows(String text) => [
        for (final r in jsonDecode(text) as List)
          Map<String, dynamic>.from(r as Map),
      ];
}
