import 'dart:ui';

/// Палитра цветов категорий (в формате `RRGGBB` без `#`).
///
/// Используется в селекторе категорий и как fallback, когда
/// `colorHex` не задан.
const List<String> kCategoryColorHexes = [
  '6759A0', // фиолетовый (seed приложения)
  'E53935', // красный
  'F57C00', // оранжевый
  'FBC02D', // жёлтый
  '43A047', // зелёный
  '039BE5', // голубой
  '5E35B1', // тёмно-фиолетовый
  '8D6E63', // коричневый
  '78909C', // серо-синий
];

/// Цвет категории по умолчанию (фиолетовый seed приложения).
const Color kDefaultCategoryColor = Color(0xFF6759A0);

/// Конвертирует hex-строку `RRGGBB` (без `#`) в [Color].
///
/// При невалидном значении возвращает [fallback].
Color colorFromHex(String? hex, {Color fallback = kDefaultCategoryColor}) {
  final value = hex?.replaceAll('#', '').trim();
  if (value == null || value.isEmpty || value.length != 6) {
    return fallback;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}

/// Фоновый цвет чипа категории — прозрачный вариант [color].
Color categoryBackground(Color color) => color.withValues(alpha: 0.12);
