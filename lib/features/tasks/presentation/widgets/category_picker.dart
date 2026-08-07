import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/services/category_color.dart';

/// Показывает bottom sheet выбора категории задачи.
///
/// Возвращает выбранный [TaskCategory], `null` — без категории
/// (если выбрали пункт «Без категории»), либо `false` (специальное
/// значение) если создали новую категорию (тогда список нужно
/// перезагрузить). Возвращает `Future<Object?>`, чтобы различить
/// `null` (без категории) и выбор «создать».
Future<Object?> showCategoryPicker({
  required BuildContext context,
  required String householdId,
  List<TaskCategory> categories = const [],
  String? selectedCategoryId,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _CategoryPickerSheet(
        householdId: householdId,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
      );
    },
  );
}

/// Результат выбора: либо [TaskCategory], либо `null` (без категории).
final class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.householdId,
    required this.categories,
    this.selectedCategoryId,
  });

  final String householdId;
  final List<TaskCategory> categories;
  final String? selectedCategoryId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

final class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late List<TaskCategory> _categories;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _categories = widget.categories;
  }

  Future<void> _createCategory(String name, String colorHex) async {
    final repository = context.read<TaskCategoryRepository>();
    setState(() => _creating = true);
    try {
      final created = await repository.create(
        CreateTaskCategoryParams(
          householdId: widget.householdId,
          name: name,
          colorHex: colorHex,
        ),
      );
      // Обновляем локальный список и возвращаем новую категорию.
      setState(() => _categories = [..._categories, created]);
      Navigator.of(context).pop(created);
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать категорию.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.label_outline, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Категория',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.block_outlined, color: cs.onSurfaceVariant),
              title: const Text('Без категории'),
              selected: widget.selectedCategoryId == null,
              onTap: () => Navigator.of(context).pop(null),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._categories.map((cat) {
                    final isSelected = cat.id == widget.selectedCategoryId;
                    final color = colorFromHex(cat.colorHex);
                    return ListTile(
                      leading: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(cat.name),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: cs.primary)
                          : null,
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(cat),
                    );
                  }),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: _creating
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Создать новую'),
              onTap: _creating ? null : _showCreateDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    await showDialog<TaskCategory>(
      context: context,
      builder: (ctx) => _CategoryCreateDialog(
        householdId: widget.householdId,
        onSubmitted: _createCategory,
      ),
    );
    // _createCategory уже делает pop, поэтому здесь ничего не делаем.
  }
}

/// Диалог создания новой категории: название + выбор цвета.
final class _CategoryCreateDialog extends StatefulWidget {
  const _CategoryCreateDialog({
    required this.householdId,
    required this.onSubmitted,
  });

  final String householdId;
  final Future<void> Function(String name, String colorHex) onSubmitted;

  @override
  State<_CategoryCreateDialog> createState() => _CategoryCreateDialogState();
}

final class _CategoryCreateDialogState extends State<_CategoryCreateDialog> {
  final _controller = TextEditingController();
  String _colorHex = kCategoryColorHexes.first;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая категория'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              hintText: 'Например: Покупки, Учёба',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Цвет'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in kCategoryColorHexes)
                InkWell(
                  onTap: () => setState(() => _colorHex = hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: _colorHex == hex
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            )
                          : null,
                    ),
                    child: _colorHex == hex
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  final name = _controller.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите название категории.')),
                    );
                    return;
                  }
                  setState(() => _submitting = true);
                  // Закрываем диалог сразу; создание продолжается в пикере.
                  Navigator.of(context).pop();
                  widget.onSubmitted(name, _colorHex);
                },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
