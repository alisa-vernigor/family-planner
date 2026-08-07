import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/services/category_color.dart';

/// Цветной чип категории задачи.
///
/// Показывает название категории на фоне её цвета. Если [category]
/// не задан — не отображается (null-safe для списков без категорий).
final class CategoryChip extends StatelessWidget {
  const CategoryChip({required this.category, super.key});

  /// Категория; `null` — чип не рендерится.
  final TaskCategory? category;

  @override
  Widget build(BuildContext context) {
    final cat = category;
    if (cat == null) return const SizedBox.shrink();

    final color = colorFromHex(cat.colorHex);
    return Container(
      decoration: BoxDecoration(
        color: categoryBackground(color),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            cat.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
