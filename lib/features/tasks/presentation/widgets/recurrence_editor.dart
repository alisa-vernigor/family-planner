import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/presentation/widgets/recurrence_summary.dart';
import 'package:family_planner/features/tasks/presentation/widgets/weekday_chip.dart';

/// Чертёж настроек повторения, заполняемый [RecurrenceEditor].
///
/// `isEnabled == false` означает «повторение выключено».
final class RecurrenceDraft extends Equatable {
  const RecurrenceDraft({
    required this.type,
    this.isEnabled = true,
    this.intervalDays = 1,
    this.weekdays = const [],
    this.startDate,
    this.endDate,
  });

  final TaskRecurrenceType type;
  final bool isEnabled;
  final int intervalDays;
  final List<int> weekdays;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Расписание повторения, или `null`, если повторение выключено.
  TaskRecurrence? buildRecurrence() {
    if (!isEnabled) {
      return null;
    }

    return switch (type) {
      TaskRecurrenceType.daily => const TaskRecurrence.daily(),
      TaskRecurrenceType.weekly => TaskRecurrence.weekly(
        weekdays: List<int>.from(weekdays)..sort(),
      ),
      TaskRecurrenceType.intervalDays => TaskRecurrence.intervalDays(
        intervalDays: intervalDays,
      ),
    };
  }

  RecurrenceDraft copyWith({
    TaskRecurrenceType? type,
    bool? isEnabled,
    int? intervalDays,
    List<int>? weekdays,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
  }) {
    return RecurrenceDraft(
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      startDate: identical(startDate, _sentinel) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _sentinel) ? this.endDate : endDate as DateTime?,
    );
  }

  @override
  List<Object?> get props => [type, isEnabled, intervalDays, weekdays, startDate, endDate];
}

const _sentinel = Object();

/// Редактор настроек повторения задачи.
///
/// Вынесен из [CreateTaskSheet], чтобы переиспользоваться в
/// [EditTaskSheet] (для повторяющихся задач). Управляет собственным
/// состоянием и сообщает результат через [onChanged].
///
/// Сохраняет стабильные ключи виджетов (recurrence_switch,
/// recurrence_type_dropdown, weekday_chip_*, recurrence_interval_field,
/// recurrence_start_date_button, recurrence_end_date_button) —
/// на них опираются виджет-тесты.
final class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    required this.onChanged,
    this.initial,
    this.enabled = true,
    this.showEnableSwitch = true,
    super.key,
  });

  /// Колбэк при любом изменении настроек.
  final ValueChanged<RecurrenceDraft> onChanged;

  /// Начальные настройки (для редактирования повторяющейся задачи).
  final RecurrenceDraft? initial;

  /// `false` — редактор заблокирован (например, при отправке).
  final bool enabled;

  /// Показывать ли переключатель «Повторять задачу».
  ///
  /// Для редактирования существующей серии переключатель скрыт —
  /// повторение уже включено.
  final bool showEnableSwitch;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

final class _RecurrenceEditorState extends State<RecurrenceEditor> {
  bool _isRecurring = false;
  TaskRecurrenceType _recurrenceType = TaskRecurrenceType.daily;
  late final TextEditingController _intervalController;
  Set<int> _selectedWeekdays = {};
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _isRecurring = initial?.isEnabled ?? false;
    _recurrenceType = initial?.type ?? TaskRecurrenceType.daily;
    _selectedWeekdays = Set<int>.of(initial?.weekdays ?? const []);
    _intervalController = TextEditingController(
      text: (initial?.intervalDays ?? 1).toString(),
    );
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  RecurrenceDraft get _draft => RecurrenceDraft(
    type: _recurrenceType,
    isEnabled: _isRecurring,
    intervalDays: int.tryParse(_intervalController.text) ?? 1,
    weekdays: List<int>.from(_selectedWeekdays),
    startDate: _startDate,
    endDate: _endDate,
  );

  void _notify() {
    widget.onChanged(_draft);
  }

  void _setRecurring(bool value) {
    setState(() {
      _isRecurring = value;
    });
    widget.onChanged(_draft);
  }

  Future<void> _pickStartDate() async {
    final reference = _startDate ?? _endDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? reference,
      firstDate: DateTime(reference.year - 1),
      lastDate: DateTime(reference.year + 5),
      helpText: 'Когда начать повторение',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _startDate = selected;
      if (_endDate != null && _endDate!.isBefore(selected)) {
        _endDate = null;
      }
    });
    _notify();
  }

  Future<void> _pickEndDate() async {
    final start = _startDate ?? _endDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? start,
      firstDate: start,
      lastDate: DateTime(start.year + 5),
      helpText: 'Когда закончить повторение',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _endDate = selected;
    });
    _notify();
  }

  void _clearStartDate() {
    setState(() {
      _startDate = null;
    });
    _notify();
  }

  void _clearEndDate() {
    setState(() {
      _endDate = null;
    });
    _notify();
  }

  void _toggleWeekday(int day, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedWeekdays.add(day);
      } else {
        _selectedWeekdays.remove(day);
      }
    });
    _notify();
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !widget.enabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showEnableSwitch)
          SwitchListTile(
            key: const Key('recurrence_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Повторять задачу'),
            subtitle: const Text('Можно будет поставить повторение на паузу позже'),
            value: _isRecurring,
            onChanged: isLoading ? null : _setRecurring,
          ),
        if (_isRecurring) ...[
          const SizedBox(height: 8),
          RecurrenceSummary(
            type: _recurrenceType,
            intervalDays: int.tryParse(_intervalController.text) ?? 1,
            weekdayCount: _selectedWeekdays.length,
            weekdays: List<int>.from(_selectedWeekdays)..sort(),
            startDate: _startDate,
            endDate: _endDate,
          ),
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
                    if (value == null) return;
                    setState(() {
                      _recurrenceType = value;
                    });
                    _notify();
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
                for (final (day, label) in const [
                  (1, 'Пн'),
                  (2, 'Вт'),
                  (3, 'Ср'),
                  (4, 'Чт'),
                  (5, 'Пт'),
                  (6, 'Сб'),
                  (7, 'Вс'),
                ])
                  WeekdayChip(
                    day: day,
                    label: label,
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
              controller: _intervalController,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Повторять каждые N дней',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_repeat_outlined),
              ),
              onChanged: (_) => _notify(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('recurrence_start_date_button'),
            onPressed: isLoading ? null : _pickStartDate,
            icon: const Icon(Icons.play_circle_outline),
            label: Text(
              _startDate == null
                  ? 'Начать повторение с даты задачи'
                  : 'Начать повторение: ${_formatDate(_startDate!)}',
            ),
          ),
          if (_startDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('clear_recurrence_start_date_button'),
                onPressed: isLoading ? null : _clearStartDate,
                child: const Text('Использовать дату задачи'),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('recurrence_end_date_button'),
            onPressed: isLoading ? null : _pickEndDate,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(
              _endDate == null
                  ? 'Закончить повторение — без срока'
                  : 'Закончить повторение: ${_formatDate(_endDate!)}',
            ),
          ),
          if (_endDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('clear_recurrence_end_date_button'),
                onPressed: isLoading ? null : _clearEndDate,
                child: const Text('Без даты окончания'),
              ),
            ),
        ],
      ],
    );
  }
}
