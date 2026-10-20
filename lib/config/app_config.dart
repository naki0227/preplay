/// Build-time configuration passed with `--dart-define` or
/// `--dart-define-from-file=config/app_config.json`.
///
/// Only public values belong here. Anything compiled into the app can be
/// extracted from the binary, so API keys (Gemini etc.) must stay on the
/// backend and never be passed in through this file.
class AppConfig {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://preplay-five.vercel.app',
  );

  // Supabase anon key is public by design; access is controlled by RLS.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String appStoreUrl =
      'https://apps.apple.com/jp/app/preplay/id6758872014';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
