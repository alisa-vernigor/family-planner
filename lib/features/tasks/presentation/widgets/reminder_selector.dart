import 'package:flutter/material.dart';

/// Значения «за сколько минут до дедлайна/начала прислать напоминание».
const reminderMinutesOptions = <int?>[null, 5, 15, 30, 60, 1440];

/// Переиспользуемый выбор напоминания о задаче.
///
/// Drop-down с вариантами «за сколько минут до начала прислать push».
/// `null` — без напоминания.
class ReminderSelector extends StatelessWidget {
  const ReminderSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      key: const Key('reminder_selector'),
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Напоминание',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notifications_outlined),
      ),
      items: reminderMinutesOptions
          .map(
            (minutes) => DropdownMenuItem(
              value: minutes,
              child: Text(_label(minutes)),
            ),
          )
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
    );
  }

  String _label(int? minutes) {
    if (minutes == null) return 'Без напоминания';
    if (minutes == 1440) return 'За день';
    if (minutes == 60) return 'За 1 час';
    return 'За $minutes мин';
  }
}
