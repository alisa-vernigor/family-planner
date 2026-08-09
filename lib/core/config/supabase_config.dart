import 'package:flutter_dotenv/flutter_dotenv.dart';

final class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final value = dotenv.isInitialized
        ? dotenv.maybeGet('SUPABASE_URL')
        : null;
    if (value != null && value.isNotEmpty) return value;
    return const String.fromEnvironment('SUPABASE_URL');
  }

  static String get publishableKey {
    final value = dotenv.isInitialized
        ? dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY')
        : null;
    if (value != null && value.isNotEmpty) return value;
    return const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  }
}