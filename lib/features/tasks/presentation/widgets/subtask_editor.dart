import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';

/// Инлайн-редактор подзадач внутри карточки задачи.
///
/// Показывает список подзадач с чекбоксами, полем добавления новой,
/// удалением по свайпу и drag & drop перестановкой (по [ReorderableListView]).
final class SubtaskEditor extends StatefulWidget {
  const SubtaskEditor({
    required this.subtasks,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    this.onReorder,
    super.key,
  });

  final List<TaskSubtask> subtasks;
  final Future<void> Function(String title) onAdd;
  final Future<void> Function(TaskSubtask subtask) onToggle;
  final Future<void> Function(String subtaskId) onDelete;
  final Future<void> Function(String taskId, List<String> orderedIds)? onReorder;

  @override
  State<SubtaskEditor> createState() => _SubtaskEditorState();
}

final class _SubtaskEditorState extends State<SubtaskEditor> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _adding) return;

    setState(() {
      _adding = true;
      _controller.clear();
    });

    await widget.onAdd(title);

    if (mounted) {
      setState(() => _adding = false);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtasks = widget.subtasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Подзадачи',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (subtasks.isNotEmpty)
              Text(
                '${subtasks.where((s) => s.isCompleted).length}/${subtasks.length}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (subtasks.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: widget.onReorder == null
                ? null
                : (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final ids = [
                      for (final s in subtasks) s.id,
                    ];
                    final item = ids.removeAt(oldIndex);
                    ids.insert(newIndex, item);
                    widget.onReorder!(widget.subtasks.first.taskId, ids);
                  },
            children: [
              for (final subtask in subtasks)
                Dismissible(
                  key: ValueKey(subtask.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: cs.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => widget.onDelete(subtask.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: ReorderableDragStartListener(
                      index: subtasks.indexOf(subtask),
                      enabled: widget.onReorder != null,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    title: Text(
                      subtask.title,
                      style: TextStyle(
                        decoration: subtask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtask.isCompleted
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: subtask.isCompleted
                          ? 'Вернуть в работу'
                          : 'Отметить выполненной',
                      icon: Icon(
                        subtask.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked_outlined,
                        color: subtask.isCompleted
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      onPressed: () => widget.onToggle(subtask),
                    ),
                  ),
                ),
            ],
          ),
        if (subtasks.isNotEmpty) const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_adding,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  hintText: 'Добавить подзадачу…',
                  isDense: true,
                  border: UnderlineInputBorder(),
                  prefixIcon: Icon(Icons.add_task_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Добавить',
              onPressed: _adding ? null : _add,
              icon: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}
