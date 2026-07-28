import 'package:flutter_dotenv/flutter_dotenv.dart';

final class ProxyApiConfig {
  ProxyApiConfig._();

  static String get apiKey {
    final value = dotenv.maybeGet('PROXYAPI_KEY');
    if (value != null && value.isNotEmpty) return value;
    return const String.fromEnvironment('PROXYAPI_KEY');
  }
}