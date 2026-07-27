import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('info не выбрасывает исключения', () {
      expect(() => AppLogger.info('сообщение'), returnsNormally);
    });

    test('debug не выбрасывает исключения', () {
      expect(() => AppLogger.debug('сообщение'), returnsNormally);
    });

    test('warning не выбрасывает исключения', () {
      expect(() => AppLogger.warning('сообщение'), returnsNormally);
    });

    test('error не выбрасывает исключения', () {
      expect(
        () => AppLogger.error('сообщение'),
        returnsNormally,
      );

      expect(
        () => AppLogger.error(
          'сообщение',
          error: Exception('ошибка'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });
}
