import 'package:flutter/material.dart';

/// Чип выбора дня недели для повторяющихся задач.
///
/// Отображает короткую метку (Пн, Вт…) и поддерживает выделение/снятие.
final class WeekdayChip extends StatelessWidget {
  const WeekdayChip({
    required this.day,
    required this.label,
    required this.selectedDays,
    required this.isEnabled,
    required this.onChanged,
    super.key,
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
