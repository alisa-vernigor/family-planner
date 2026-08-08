import 'package:flutter/material.dart';

/// Поле выбора времени начала задачи (для календарной шкалы).
///
/// `null` — задача без времени / весь день (показывается в ряду «Весь день»).
/// Выбранное время отображается в кнопке и убирается кнопкой «Убрать время».
final class StartTimeField extends StatelessWidget {
  const StartTimeField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final Duration? value;
  final void Function(Duration?) onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final initial = value == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: value!.inHours, minute: value!.inMinutes % 60);

    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (selected == null) return;
    onChanged(Duration(hours: selected.hour, minutes: selected.minute));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? () => _pick(context) : null,
          icon: Icon(
            value == null ? Icons.access_time_outlined : Icons.schedule,
            color: value == null ? cs.onSurfaceVariant : cs.primary,
          ),
          label: Text(
            value == null
                ? 'Время начала (весь день)'
                : 'Начало: ${_formatTime(value!)}',
            style: TextStyle(
              color: value == null ? cs.onSurfaceVariant : cs.onSurface,
            ),
          ),
        ),
        if (value != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: enabled
                  ? () => onChanged(null)
                  : null,
              child: const Text('Убрать время'),
            ),
          ),
      ],
    );
  }

  String _formatTime(Duration time) {
    final h = time.inHours.toString().padLeft(2, '0');
    final m = (time.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
