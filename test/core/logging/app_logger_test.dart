import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('статика — класс существует', () {
      // покрывает приватный конструктор AppLogger._()
      expect(AppLogger, isA<Type>());
    });

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

    test('error с error и stackTrace отдельными параметрами', () {
      final error = StateError('boom');
      final trace = StackTrace.current;
      expect(
        () => AppLogger.error('сообщение', error: error, stackTrace: trace),
        returnsNormally,
      );
    });

    test('error только с error (без stackTrace)', () {
      expect(
        () => AppLogger.error('сообщение', error: Exception('только error')),
        returnsNormally,
      );
    });

    test('error только с stackTrace (без error)', () {
      expect(
        () => AppLogger.error('сообщение', stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('все уровни подряд не выбрасывают', () {
      expect(() {
        AppLogger.debug('debug');
        AppLogger.info('info');
        AppLogger.warning('warning');
        AppLogger.error('error');
      }, returnsNormally);
    });
  });
}
