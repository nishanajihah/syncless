/// Compile-time configuration supplied with `--dart-define`.
///
/// Supabase's anonymous key is designed for client applications; Row Level Security and
/// Edge Function authorization remain the security boundary. No OpenAI or
/// Supabase service-role credential belongs in this application.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    final uri = Uri.tryParse(supabaseUrl);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError(
        'SUPABASE_URL is required. Supply it with --dart-define=SUPABASE_URL=…',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is required. Supply it with --dart-define=SUPABASE_ANON_KEY=…',
      );
    }
  }
}
