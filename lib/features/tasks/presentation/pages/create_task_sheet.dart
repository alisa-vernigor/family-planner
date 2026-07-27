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
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';

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
  DateTime? _recurrenceStartDate;
  DateTime? _recurrenceEndDate;

  final _recurrenceIntervalController = TextEditingController(text: '1');

  bool _isRecurring = false;
  TaskRecurrenceType _recurrenceType = TaskRecurrenceType.daily;
  final Set<int> _selectedWeekdays = {};

  List<HouseholdMember> _members = [];
  String? _assignedMemberId;
  bool _isPinned = false;

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
    _recurrenceIntervalController.dispose();
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

  Future<void> _pickRecurrenceStartDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _recurrenceStartDate ?? _deadline ?? widget.plannedFor,
      firstDate: widget.plannedFor,
      lastDate: DateTime(widget.plannedFor.year + 5),
      helpText: 'Когда начать повторение',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _recurrenceStartDate = selectedDate;

      if (_recurrenceEndDate != null &&
          _recurrenceEndDate!.isBefore(selectedDate)) {
        _recurrenceEndDate = null;
      }
    });
  }

  Future<void> _pickRecurrenceEndDate() async {
    final startDate = _recurrenceStartDate ?? _deadline ?? widget.plannedFor;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? startDate,
      firstDate: startDate,
      lastDate: DateTime(startDate.year + 5),
      helpText: 'Когда закончить повторение',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _recurrenceEndDate = selectedDate;
    });
  }

  void _clearRecurrenceStartDate() {
    setState(() {
      _recurrenceStartDate = null;
    });
  }

  void _clearRecurrenceEndDate() {
    setState(() {
      _recurrenceEndDate = null;
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

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day.$month.$year';
  }

  TaskRecurrence? _buildRecurrence() {
    if (!_isRecurring) {
      return null;
    }

    return switch (_recurrenceType) {
      TaskRecurrenceType.daily => const TaskRecurrence.daily(),
      TaskRecurrenceType.weekly => TaskRecurrence.weekly(
        weekdays: _selectedWeekdays.toList()..sort(),
      ),
      TaskRecurrenceType.intervalDays => TaskRecurrence.intervalDays(
        intervalDays: int.tryParse(_recurrenceIntervalController.text) ?? 1,
      ),
    };
  }

  void _toggleWeekday(int day, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedWeekdays.add(day);
      } else {
        _selectedWeekdays.remove(day);
      }
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_isRecurring &&
        _recurrenceType == TaskRecurrenceType.weekly &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день недели.')),
      );
      return;
    }

    if (_isRecurring &&
        _recurrenceType == TaskRecurrenceType.intervalDays &&
        (int.tryParse(_recurrenceIntervalController.text) ?? 0) <= 0) {
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
        estimatedDurationMinutes: int.parse(_durationController.text),
        plannedFor: widget.plannedFor,
        deadline: _deadline,
        assignedMemberId: _assignedMemberId,
        pinnedMemberId: _isPinned ? _assignedMemberId : null,
        recurrence: _buildRecurrence(),
        recurrenceStartDate: _recurrenceStartDate,
        recurrenceEndDate: _recurrenceEndDate,
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
            Navigator.of(context).pop(true);

          case CreateTaskFailure(:final message):
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
                          labelText: 'Длительность, минут',
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
                      SwitchListTile(
                        key: const Key('recurrence_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Повторять задачу'),
                        subtitle: const Text(
                          'Можно будет поставить повторение на паузу позже',
                        ),
                        value: _isRecurring,
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _isRecurring = value;
                                });
                              },
                      ),
                      if (_isRecurring) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<TaskRecurrenceType>(
                          key: const Key('recurrence_type_dropdown'),
                          initialValue: _recurrenceType,
                          decoration: const InputDecoration(
                            labelText: 'Как повторять',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.repeat_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TaskRecurrenceType.daily,
                              child: Text('Каждый день'),
                            ),
                            DropdownMenuItem(
                              value: TaskRecurrenceType.weekly,
                              child: Text('В выбранные дни недели'),
                            ),
                            DropdownMenuItem(
                              value: TaskRecurrenceType.intervalDays,
                              child: Text('Раз в несколько дней'),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _recurrenceType = value;
                                  });
                                },
                        ),
                        if (_recurrenceType == TaskRecurrenceType.weekly) ...[
                          const SizedBox(height: 16),
                          const Text('Дни недели'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _WeekdayChip(
                                day: 1,
                                label: 'Пн',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 2,
                                label: 'Вт',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 3,
                                label: 'Ср',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 4,
                                label: 'Чт',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 5,
                                label: 'Пт',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 6,
                                label: 'Сб',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                              _WeekdayChip(
                                day: 7,
                                label: 'Вс',
                                selectedDays: _selectedWeekdays,
                                isEnabled: !isLoading,
                                onChanged: _toggleWeekday,
                              ),
                            ],
                          ),
                        ],
                        if (_recurrenceType == TaskRecurrenceType.intervalDays) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('recurrence_interval_field'),
                            controller: _recurrenceIntervalController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Повторять каждые N дней',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event_repeat_outlined),
                            ),
                            validator: (value) {
                              if (!_isRecurring ||
                                  _recurrenceType !=
                                      TaskRecurrenceType.intervalDays) {
                                return null;
                              }

                              final interval = int.tryParse(value ?? '');

                              if (interval == null || interval <= 0) {
                                return 'Введите целое число больше нуля.';
                              }

                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('recurrence_start_date_button'),
                          onPressed: isLoading ? null : _pickRecurrenceStartDate,
                          icon: const Icon(Icons.play_circle_outline),
                          label: Text(
                            _recurrenceStartDate == null
                                ? 'Начать повторение с даты задачи'
                                : 'Начать повторение: '
                                      '${_formatDate(_recurrenceStartDate!)}',
                          ),
                        ),
                        if (_recurrenceStartDate != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key(
                                'clear_recurrence_start_date_button',
                              ),
                              onPressed: isLoading
                                  ? null
                                  : _clearRecurrenceStartDate,
                              child: const Text('Использовать дату задачи'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('recurrence_end_date_button'),
                          onPressed: isLoading ? null : _pickRecurrenceEndDate,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(
                            _recurrenceEndDate == null
                                ? 'Закончить повторение — без срока'
                                : 'Закончить повторение: '
                                      '${_formatDate(_recurrenceEndDate!)}',
                          ),
                        ),
                        if (_recurrenceEndDate != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key(
                                'clear_recurrence_end_date_button',
                              ),
                              onPressed: isLoading
                                  ? null
                                  : _clearRecurrenceEndDate,
                              child: const Text('Без даты окончания'),
                            ),
                          ),
                        ],
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

final class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.day,
    required this.label,
    required this.selectedDays,
    required this.isEnabled,
    required this.onChanged,
  });

  final int day;
  final String label;
  final Set<int> selectedDays;
  final bool isEnabled;
  final void Function(int day, bool isSelected) onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: Key('weekday_chip_$day'),
      label: Text(label),
      selected: selectedDays.contains(day),
      onSelected: isEnabled
          ? (isSelected) {
              onChanged(day, isSelected);
            }
          : null,
    );
  }
}
