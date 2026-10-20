import 'dart:io';

/// Reads environment variables, then overrides them with values from a local
/// `.env` file if there is one (KEY=value per line, # for comments).
Map<String, String> loadEnv([String path = '.env']) {
  final result = <String, String>{...Platform.environment};
  final file = File(path);
  if (!file.existsSync()) return result;

  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;

    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    final quoted = value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    if (quoted) value = value.substring(1, value.length - 1);
    result[key] = value;
  }
  return result;
}
