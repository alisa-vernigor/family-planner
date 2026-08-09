import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/import_export/domain/entities/task_import_result.dart';

void main() {
  group('TaskImportResult', () {
    test('по умолчанию всё ноль и без ошибок', () {
      const r = TaskImportResult();

      expect(r.imported, 0);
      expect(r.skipped, 0);
      expect(r.errors, isEmpty);
      expect(r.hasErrors, isFalse);
    });

    test('hasErrors true когда есть ошибки', () {
      const r = TaskImportResult(errors: ['Ошибка']);

      expect(r.hasErrors, isTrue);
    });

    test('copyWith сохраняет не переданные поля', () {
      const base = TaskImportResult(imported: 5, skipped: 2, errors: ['e']);

      final updated = base.copyWith(imported: 7);

      expect(updated.imported, 7);
      expect(updated.skipped, 2);
      expect(updated.errors, ['e']);
    });

    test('copyWith может заменить errors', () {
      const base = TaskImportResult(errors: ['e1']);
      final updated = base.copyWith(errors: []);

      expect(updated.errors, isEmpty);
    });

    test('equals по полям', () {
      const a = TaskImportResult(imported: 1, skipped: 0);
      const b = TaskImportResult(imported: 1, skipped: 0);
      const c = TaskImportResult(imported: 2);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
