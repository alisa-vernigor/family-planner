import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/update_task_state.dart';

Future<bool?> showEditTaskSheet({
  required BuildContext context,
  required Task task,
}) {
  final repository = context.read<TaskRepository>();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return BlocProvider(
        create: (_) => UpdateTaskCubit(
          updateTaskUseCase: UpdateTaskUseCase(repository: repository),
        ),
        child: EditTaskSheet(task: task),
      );
    },
  );
}

final class EditTaskSheet extends StatefulWidget {
  const EditTaskSheet({required this.task, super.key});

  final Task task;

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

final class _EditTaskSheetState extends State<EditTaskSheet> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;

  late DateTime? _deadline;

  @override
  void initState() {
    super.initState();

    _formKey = GlobalKey<FormState>();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _durationController = TextEditingController(
      text: widget.task.estimatedDurationMinutes.toString(),
    );
    _deadline = widget.task.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? widget.task.plannedFor,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _deadline == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(_deadline!),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _deadline = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _clearDeadline() {
    setState(() {
      _deadline = null;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final updatedTask = Task(
      id: widget.task.id,
      householdId: widget.task.householdId,
      title: _titleController.text,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text,
      estimatedDurationMinutes: int.parse(_durationController.text),
      plannedFor: _deadline ?? widget.task.plannedFor,
      deadline: _deadline,
      allowedMemberIds: widget.task.allowedMemberIds,
      assignedMemberId: widget.task.assignedMemberId,
      status: widget.task.status,
      createdAt: widget.task.createdAt,
      completedAt: widget.task.completedAt,
    );

    context.read<UpdateTaskCubit>().update(task: updatedTask);
  }

  String _formatDeadline(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateTaskCubit, UpdateTaskState>(
      listener: (context, state) {
        switch (state) {
          case UpdateTaskSuccess():
            Navigator.of(context).pop(true);

          case UpdateTaskFailure(:final message):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));

          case UpdateTaskInitial():
          case UpdateTaskInProgress():
            break;
        }
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: BlocBuilder<UpdateTaskCubit, UpdateTaskState>(
              builder: (context, state) {
                final isLoading = state is UpdateTaskInProgress;

                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Редактировать задачу',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('edit_task_title_field'),
                        controller: _titleController,
                        enabled: !isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.checklist_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите название задачи.';
                          }

                          if (value.trim().length > 160) {
                            return 'Название должно быть не длиннее 160 символов.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('edit_task_description_field'),
                        controller: _descriptionController,
                        enabled: !isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Описание — необязательно',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        validator: (value) {
                          if (value != null && value.length > 2000) {
                            return 'Описание должно быть не длиннее 2000 символов.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('edit_task_duration_field'),
                        controller: _durationController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Длительность, минут',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (value) {
                          final duration = int.tryParse(value ?? '');

                          if (duration == null || duration <= 0) {
                            return 'Введите длительность больше нуля.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _pickDeadline,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          _deadline == null
                              ? 'Добавить дедлайн'
                              : 'Дедлайн: ${_formatDeadline(_deadline!)}',
                        ),
                      ),
                      if (_deadline != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : _clearDeadline,
                            child: const Text('Убрать дедлайн'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const Key('save_task_button'),
                        onPressed: isLoading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Сохранить изменения'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
