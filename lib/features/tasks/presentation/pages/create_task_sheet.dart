import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_state.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:family_planner/features/tasks/presentation/widgets/category_field.dart';
import 'package:family_planner/features/tasks/presentation/widgets/priority_selector.dart';
import 'package:family_planner/features/tasks/presentation/widgets/recurrence_editor.dart';
import 'package:family_planner/features/tasks/presentation/widgets/reminder_selector.dart';

Future<bool?> showCreateTaskSheet({
  required BuildContext context,
  required String householdId,
  required DateTime plannedFor,
}) {
  final repository = context.read<TaskRepository>();
  final householdRepository = context.read<HouseholdRepository>();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return BlocProvider(
        create: (_) => CreateTaskCubit(
          createTaskUseCase: CreateTaskUseCase(repository: repository),
        ),
        child: CreateTaskSheet(
          householdId: householdId,
          plannedFor: plannedFor,
          householdRepository: householdRepository,
        ),
      );
    },
  );
}

final class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({
    required this.householdId,
    required this.plannedFor,
    required this.householdRepository,
    super.key,
  });

  final String householdId;
  final DateTime plannedFor;
  final HouseholdRepository householdRepository;

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

final class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  DateTime? _deadline;
  int? _reminderMinutesBefore;
  String? _categoryId;
  RecurrenceDraft _recurrenceDraft = const RecurrenceDraft(
    type: TaskRecurrenceType.daily,
    isEnabled: false,
  );

  List<HouseholdMember> _members = [];
  String? _assignedMemberId;
  bool _isPinned = false;
  bool _isSubmitting = false;
  EisenhowerPriority? _priority;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.householdRepository.getMembers(
        householdId: widget.householdId,
      );
      if (mounted) {
        setState(() => _members = members);
      }
    } catch (exception, stackTrace) {
      AppLogger.warning(
        'Не удалось загрузить участников для назначения',
      );
      AppLogger.error(
        'Ошибка загрузки участников',
        error: exception,
        stackTrace: stackTrace,
      );
    }
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
      initialDate: _deadline ?? widget.plannedFor,
      firstDate: widget.plannedFor,
      lastDate: DateTime(widget.plannedFor.year + 5),
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

  Future<void> _pickAssignee() async {
    final picked = await showAssigneePicker(
      context: context,
      members: _members,
      currentAssigneeId: _assignedMemberId,
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (picked.isEmpty) {
        _assignedMemberId = null;
        _isPinned = false;
      } else {
        _assignedMemberId = picked;
      }
    });
  }

  String? _assigneeName() {
    if (_assignedMemberId == null) return null;
    final member = _members.where((m) => m.profileId == _assignedMemberId);
    return member.isNotEmpty ? member.first.displayName : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_isSubmitting) return;
    _isSubmitting = true;

    final recurrence = _recurrenceDraft.buildRecurrence();
    final isRecurring = recurrence != null;

    if (isRecurring &&
        recurrence.type == TaskRecurrenceType.weekly &&
        recurrence.weekdays.isEmpty) {
      _isSubmitting = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день недели.')),
      );
      return;
    }

    if (isRecurring &&
        recurrence.type == TaskRecurrenceType.intervalDays &&
        recurrence.intervalDays! <= 0) {
      _isSubmitting = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите интервал повторения больше нуля.'),
        ),
      );
      return;
    }

    context.read<CreateTaskCubit>().create(
      params: CreateTaskParams(
        householdId: widget.householdId,
        title: _titleController.text,
        description: _descriptionController.text,
        estimatedDurationMinutes: int.tryParse(_durationController.text) ?? 0,
        plannedFor: widget.plannedFor,
        deadline: _deadline,
        assignedMemberId: _assignedMemberId,
        pinnedMemberId: _isPinned ? _assignedMemberId : null,
        recurrence: recurrence,
        recurrenceStartDate: _recurrenceDraft.startDate,
        recurrenceEndDate: _recurrenceDraft.endDate,
        priority: _priority,
        reminderMinutesBefore: _reminderMinutesBefore,
        categoryId: _categoryId,
      ),
    );
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
    return BlocListener<CreateTaskCubit, CreateTaskState>(
      listener: (context, state) {
        switch (state) {
          case CreateTaskSuccess():
            _isSubmitting = false;
            Navigator.of(context).pop(true);

          case CreateTaskFailure(:final message):
            _isSubmitting = false;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));

          case CreateTaskInitial():
          case CreateTaskInProgress():
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
            child: BlocBuilder<CreateTaskCubit, CreateTaskState>(
              builder: (context, state) {
                final isLoading = state is CreateTaskInProgress;

                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Новая задача',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titleController,
                        enabled: !isLoading,
                        autofocus: true,
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
                        controller: _durationController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Длительность работы, минут',
                          hintText: 'Например: 30',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (value) {
                          final duration = int.tryParse(value ?? '');

                          if (duration == null || duration <= 0) {
                            return 'Введите длительность больше нуля.';
                          }

                          if (duration > 1440) {
                            return 'Максимум 24 часа (1440 минут).';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _pickAssignee,
                        icon: Icon(
                          _assignedMemberId != null
                              ? Icons.person_outlined
                              : Icons.person_add_outlined,
                        ),
                        label: Text(
                          _assigneeName() ?? 'Назначить ответственного',
                        ),
                      ),
                      if (_assignedMemberId != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                key: const Key('pin_assignee_switch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Закрепить'),
                                subtitle: const Text(
                                  'Не будет перераспределяться',
                                ),
                                value: _isPinned,
                                onChanged: isLoading
                                    ? null
                                    : (value) {
                                        setState(() => _isPinned = value);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      RecurrenceEditor(
                        key: const Key('create_recurrence_editor'),
                        enabled: !isLoading,
                        initial: _recurrenceDraft,
                        onChanged: (draft) {
                          setState(() => _recurrenceDraft = draft);
                        },
                      ),
                      const SizedBox(height: 16),
                      PrioritySelector(
                        value: _priority,
                        onChanged: (p) => setState(() => _priority = p),
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
                      const SizedBox(height: 16),
                      ReminderSelector(
                        value: _reminderMinutesBefore,
                        enabled: !isLoading,
                        onChanged: (minutes) {
                          setState(() => _reminderMinutesBefore = minutes);
                        },
                      ),
                      const SizedBox(height: 16),
                      CategoryField(
                        key: const Key('create_category_field'),
                        householdId: widget.householdId,
                        selectedCategoryId: _categoryId,
                        enabled: !isLoading,
                        onChanged: (categoryId) {
                          setState(() => _categoryId = categoryId);
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
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
                              : const Text('Создать задачу'),
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
