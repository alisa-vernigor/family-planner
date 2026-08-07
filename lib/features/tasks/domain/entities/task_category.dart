import 'package:equatable/equatable.dart';

/// Категория задачи (семейный словарь с цветом).
///
/// Справочные данные household'а: создаются в `task_categories`,
/// каждая задача ссылается на категорию через `category_id`.
final class TaskCategory extends Equatable {
  const TaskCategory({
    required this.id,
    required this.householdId,
    required this.name,
    this.colorHex,
    this.iconName,
  });

  final String id;
  final String householdId;
  final String name;

  /// Цвет в hex-формате `#RRGGBB` (без `#`). `null` — цвет по умолчанию.
  final String? colorHex;

  /// Имя Material-иконки (например, `shopping_cart`). `null` — дефолт.
  final String? iconName;

  @override
  List<Object?> get props => [id, householdId, name, colorHex, iconName];
}
