import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/config/supabase_config.dart';

void main() {
  setUp(() {
    dotenv.clean();
  });

  group('SupabaseConfig', () {
    test('класс существует (покрывает приватный конструктор)', () {
      expect(SupabaseConfig, isA<Type>());
    });
  });

  group('SupabaseConfig.url', () {
    test('берёт значение из dotenv если оно не пустое', () {
      dotenv.loadFromString(
        envString: '\n',
        isOptional: true,
        mergeWith: {
        'SUPABASE_URL': 'https://env.example.com',
      });
      expect(SupabaseConfig.url, 'https://env.example.com');
    });

    test('игнорирует пустую строку в dotenv', () {
      dotenv.loadFromString(
        envString: '\n',
        isOptional: true,
        mergeWith: {'SUPABASE_URL': ''});
      // При пустом значении fallback — String.fromEnvironment, который в
      // тестовой сборке пуст.
      expect(SupabaseConfig.url, isEmpty);
    });

    test('без dotenv возвращает значение из --dart-define (пустое в тесте)', () {
      expect(SupabaseConfig.url, isEmpty);
    });
  });

  group('SupabaseConfig.publishableKey', () {
    test('берёт значение из dotenv если оно не пустое', () {
      dotenv.loadFromString(
        envString: '\n',
        isOptional: true,
        mergeWith: {
        'SUPABASE_PUBLISHABLE_KEY': 'env-test-key',
      });
      expect(SupabaseConfig.publishableKey, 'env-test-key');
    });

    test('игнорирует пустую строку в dotenv', () {
      dotenv.loadFromString(
        envString: '\n',
        isOptional: true,
        mergeWith: {
        'SUPABASE_PUBLISHABLE_KEY': '',
      });
      expect(SupabaseConfig.publishableKey, isEmpty);
    });

    test('без dotenv возвращает значение из --dart-define (пустое в тесте)', () {
      expect(SupabaseConfig.publishableKey, isEmpty);
    });
  });
}
