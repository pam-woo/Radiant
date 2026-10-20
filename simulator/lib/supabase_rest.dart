import 'dart:convert';

import 'package:http/http.dart' as http;

class SupabaseException implements Exception {
  SupabaseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal Supabase REST (PostgREST) client for the simulator.
///
/// It uses the secret/service key, which bypasses row level security, so it
/// must only ever run on your own machine.
class SupabaseRest {
  SupabaseRest({required String url, required this.key, http.Client? client})
      : baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url,
        _client = client ?? http.Client();

  final String baseUrl;
  final String key;
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  Map<String, String> _headers({String? prefer}) => {
        'apikey': key,
        // Legacy keys are JWTs and also go in Authorization. The newer
        // secret keys (sb_secret_...) only use the apikey header.
        if (key.startsWith('eyJ')) 'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        if (prefer != null) 'Prefer': prefer,
      };

  /// Inserts rows, or updates them when [onConflict] matches an existing row.
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required String onConflict,
  }) async {
    if (rows.isEmpty) return;
    final response = await _client
        .post(
          Uri.parse('$baseUrl/rest/v1/$table?on_conflict=$onConflict'),
          headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
          body: jsonEncode(rows),
        )
        .timeout(_timeout);
    _check(response, 'upsert into $table');
  }

  Future<void> insert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final response = await _client
        .post(
          Uri.parse('$baseUrl/rest/v1/$table'),
          headers: _headers(prefer: 'return=minimal'),
          body: jsonEncode(rows),
        )
        .timeout(_timeout);
    _check(response, 'insert into $table');
  }

  /// Deletes rows matching a PostgREST [filter] such as `id=gt.0` or
  /// `intersection_id=in.(1,2)`. A filter is required on purpose.
  Future<void> delete(String table, String filter) async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/rest/v1/$table?$filter'),
          headers: _headers(prefer: 'return=minimal'),
        )
        .timeout(_timeout);
    _check(response, 'delete from $table');
  }

  void close() => _client.close();

  void _check(http.Response response, String what) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseException(
          '$what failed (${response.statusCode}): ${response.body}');
    }
  }
}
