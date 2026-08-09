import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/services/category_color.dart';

void main() {
  group('kCategoryColorHexes', () {
    test('содержит seed-фиолетовый первым и не пуста', () {
      expect(kCategoryColorHexes, isNotEmpty);
      expect(kCategoryColorHexes.first, '6759A0');
    });
  });

  group('colorFromHex', () {
    test('конвертирует валидный hex без #', () {
      expect(colorFromHex('E53935'), const Color(0xFFE53935));
    });

    test('принимает hex с #', () {
      expect(colorFromHex('#039BE5'), const Color(0xFF039BE5));
    });

    test('игнорирует пробелы', () {
      expect(colorFromHex(' 43A047 '), const Color(0xFF43A047));
    });

    test('null → fallback по умолчанию', () {
      expect(colorFromHex(null), kDefaultCategoryColor);
    });

    test('пустая строка → fallback по умолчанию', () {
      expect(colorFromHex(''), kDefaultCategoryColor);
    });

    test('неверная длина → fallback по умолчанию', () {
      expect(colorFromHex('ABC'), kDefaultCategoryColor);
      expect(colorFromHex('1234567'), kDefaultCategoryColor);
    });

    test('не-хекс символы → fallback по умолчанию', () {
      expect(colorFromHex('GGGGGG'), kDefaultCategoryColor);
    });

    test('кастомный fallback используется', () {
      expect(
        colorFromHex(null, fallback: const Color(0xFFFF0000)),
        const Color(0xFFFF0000),
      );
    });
  });

  group('categoryBackground', () {
    test('возвращает прозрачный вариант цвета (alpha ≈ 0.12)', () {
      final bg = categoryBackground(const Color(0xFF6759A0));
      expect(bg.r, closeTo(0.4039, 0.001));
      expect(bg.g, closeTo(0.3490, 0.001));
      expect(bg.b, closeTo(0.6275, 0.001));
      expect(bg.a, closeTo(0.12, 0.01));
    });
  });
}
