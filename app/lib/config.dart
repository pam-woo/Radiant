/// Supabase settings, passed in at build time:
///   flutter run --dart-define-from-file=env.json
/// Only the publishable (anon) key belongs here, never the secret key.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
