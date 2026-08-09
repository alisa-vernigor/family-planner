import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';

/// JSON-схема импорта/экспорта задач (формат дружелюбный к нейросетям):
///
/// ```json
/// {
///   "version": 1,
///   "tasks": [
///     {
///       "title": "Помыть посуду",
///       "description": "…",
///       "date": "2026-08-09",           // YYYY-MM-DD; без даты → сегодня
///       "time": "18:00",                 // HH:MM; время начала
///       "deadline": "2026-08-09T20:00",  // ISO datetime
///       "duration_minutes": 30,          // дефолт 30
///       "priority": 2,                   // 1–4 (Эйзенхауэр) или "high"/"medium"/"low"
///       "assignee": "Мама",              // имя участника семьи
///       "category": "Кухня",             // имя категории (создастся при отсутствии)
///       "subtasks": ["Мыло", "Губка"]    // подзадачи
///     }
///   ]
/// }
/// ```
final class TaskTransferFile extends Equatable {
  const TaskTransferFile({
    this.version = 1,
    required this.tasks,
  });

  final int version;
  final List<TaskTransferItem> tasks;

  factory TaskTransferFile.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    return TaskTransferFile(
      version: json['version'] as int? ?? 1,
      tasks: rawTasks
          .map(
            (t) => TaskTransferItem.fromJson(t as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'tasks': tasks.map((t) => t.toJson()).toList(growable: false),
    };
  }

  String toJsonString() {
    return _jsonEncodePretty(toJson());
  }

  @override
  List<Object?> get props => [version, tasks];
}

/// Одна задача в формате импорта/экспорта.
final class TaskTransferItem extends Equatable {
  const TaskTransferItem({
    required this.title,
    required this.durationMinutes,
    this.description,
    this.date,
    this.time,
    this.deadline,
    this.priority,
    this.assignee,
    this.category,
    this.subtasks = const [],
  });

  final String title;
  final String? description;

  /// Дата задачи (дата-часть). `null` — «сегодня».
  final DateTime? date;

  /// Время начала (минуты от полуночи). `null` — весь день.
  final Duration? time;

  final DateTime? deadline;
  final int durationMinutes;

  /// Приоритет Эйзенхауэра (1–4). `null` — по умолчанию (4).
  final EisenhowerPriority? priority;

  /// Имя ответственного (по `displayName` участника семьи).
  final String? assignee;

  /// Имя категории (по `name`).
  final String? category;

  final List<String> subtasks;

  factory TaskTransferItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '').trim();
    final rawDate = json['date'] as String?;
    final rawTime = json['time'] as String?;
    final rawDeadline = json['deadline'] as String?;
    final rawDuration = json['duration_minutes'];
    final rawPriority = json['priority'];
    final rawSubtasks = json['subtasks'] as List<dynamic>? ?? const [];

    return TaskTransferItem(
      title: title,
      description: (json['description'] as String?)?.trim(),
      date: _parseDateOnly(rawDate),
      time: _parseTime(rawTime),
      deadline: _parseDeadline(rawDeadline),
      durationMinutes: _parseDuration(rawDuration),
      priority: _parsePriority(rawPriority),
      assignee: (json['assignee'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim(),
      subtasks: rawSubtasks
          .map((s) => (s as String).trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (date != null) 'date': _formatDateOnly(date!),
      if (time != null) 'time': _formatTime(time!),
      if (deadline != null) 'deadline': _formatDeadline(deadline!),
      'duration_minutes': durationMinutes,
      if (priority != null) 'priority': priority!.value,
      if (assignee != null && assignee!.isNotEmpty) 'assignee': assignee,
      if (category != null && category!.isNotEmpty) 'category': category,
      if (subtasks.isNotEmpty) 'subtasks': subtasks,
    };
  }

  @override
  List<Object?> get props => [
    title,
    description,
    date,
    time,
    deadline,
    durationMinutes,
    priority,
    assignee,
    category,
    subtasks,
  ];
}

// ── Парсинг/форматирование ─────────────────────────────────

/// `"2026-08-09"` → дата (UTC-дата-часть, время 00:00).
DateTime? _parseDateOnly(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// `"18:00"` → Duration (минуты от полуночи).
Duration? _parseTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.isEmpty) return null;
  final h = int.tryParse(parts[0]);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (h == null || m == null) return null;
  return Duration(hours: h, minutes: m);
}

DateTime? _parseDeadline(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;
  return dt.isUtc ? dt.toLocal() : dt;
}

int _parseDuration(dynamic raw) {
  final value = raw is int ? raw : int.tryParse('$raw');
  if (value == null || value <= 0) return 30;
  return value.clamp(1, 1440);
}

EisenhowerPriority? _parsePriority(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return EisenhowerPriority.fromValue(raw);
  switch (raw.toString().trim().toLowerCase()) {
    case 'high':
    case 'срочно':
      return EisenhowerPriority.urgentImportant;
    case 'medium':
    case 'важно':
      return EisenhowerPriority.notUrgentImportant;
    case 'low':
      return EisenhowerPriority.urgentNotImportant;
    case 'none':
      return null;
    default:
      return EisenhowerPriority.fromValue(int.tryParse(raw.toString()));
  }
}

String _formatDateOnly(DateTime dt) {
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

String _formatTime(Duration time) {
  final h = time.inHours.toString().padLeft(2, '0');
  final m = (time.inMinutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDeadline(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$m-${d}T$h:$min';
}

String _jsonEncodePretty(Map<String, dynamic> json) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(json);
}
