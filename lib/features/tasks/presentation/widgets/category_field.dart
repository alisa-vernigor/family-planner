import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';

import 'category_chip.dart';
import 'category_picker.dart';

/// Поле выбора категории для форм задачи.
///
/// Самостоятельно загружает категории семьи, показывает текущий выбор
/// цветным чипом, открывает [showCategoryPicker] и поддерживает создание
/// новой категории. Сообщает о выборе через [onChanged].
final class CategoryField extends StatefulWidget {
  const CategoryField({
    required this.householdId,
    required this.onChanged,
    this.selectedCategoryId,
    this.enabled = true,
    super.key,
  });

  final String householdId;
  final ValueChanged<String?> onChanged;
  final String? selectedCategoryId;
  final bool enabled;

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

final class _CategoryFieldState extends State<CategoryField> {
  List<TaskCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CategoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repository = context.read<TaskCategoryRepository>();
      final categories = await repository.getForHousehold(widget.householdId);
      if (mounted) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить категории.')),
        );
      }
    }
  }

  TaskCategory? get _selected {
    final id = widget.selectedCategoryId;
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pick() async {
    final result = await showCategoryPicker(
      context: context,
      householdId: widget.householdId,
      categories: _categories,
      selectedCategoryId: widget.selectedCategoryId,
    );

    if (result == null || !mounted) return;

    if (result is TaskCategory) {
      widget.onChanged(result.id);
      // Категория могла быть создана в пикере — обновляем локальный список.
      if (!_categories.any((c) => c.id == result.id)) {
        setState(() => _categories = [..._categories, result]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: widget.enabled ? _pick : null,
          icon: const Icon(Icons.label_outline),
          label: Text(
            selected != null
                ? selected.name
                : 'Категория — необязательно',
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (selected != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Цветной чип выбранной категории.
                CategoryChip(category: selected),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.enabled
                      ? () => widget.onChanged(null)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
