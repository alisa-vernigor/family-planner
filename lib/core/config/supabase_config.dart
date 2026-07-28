import 'package:flutter_dotenv/flutter_dotenv.dart';

final class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final value = dotenv.maybeGet('SUPABASE_URL');
    if (value != null && value.isNotEmpty) return value;
    return const String.fromEnvironment('SUPABASE_URL');
  }

  static String get publishableKey {
    final value = dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY');
    if (value != null && value.isNotEmpty) return value;
    return const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  }
}