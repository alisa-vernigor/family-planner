import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../logging/app_logger.dart';
import 'package:family_planner/features/tasks/tasks.dart';

bool get _isSupportedPlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Локальные push-уведомления о напоминаниях к задачам.
///
/// Планирует уведомление за [Task.reminderMinutesBefore] минут до дедлайна
/// (или до начала задачи, если дедлайна нет).
///
/// Уведомления локальные — работают офлайн, но только на этом устройстве.
final class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'task_reminders';
  static const _channelName = 'Напоминания о задачах';
  static const _channelDescription = 'Уведомления о задачах перед дедлайном';

  /// Инициализирует плагин и запрашивает разрешение на уведомления.
  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation('Europe/Moscow'),
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(settings: settings);

      _initialized = true;
      AppLogger.info('ReminderService инициализирован');
    } catch (e) {
      AppLogger.warning('ReminderService: не удалось инициализировать: $e');
    }
  }

  /// Планирует уведомление о задаче.
  ///
  /// Сработает за [minutesBefore] минут до [scheduledFor] (дедлайн или начало).
  /// Возвращает id уведомления (null — если не удалось запланировать).
  Future<int?> schedule({
    required String taskId,
    required String title,
    required DateTime scheduledFor,
    required int minutesBefore,
  }) async {
    if (!_initialized) return null;

    final id = _notificationId(taskId);
    final fireAt = scheduledFor.subtract(Duration(minutes: minutesBefore));

    // Уведомление в прошлом не планируем.
    if (fireAt.isBefore(DateTime.now())) return null;

    await _plugin.zonedSchedule(
      id: id,
      title: 'Задача: $title',
      body: 'Напоминание о задаче через $minutesBefore мин',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return id;
  }

  /// Отменяет уведомление для задачи.
  Future<void> cancel(String taskId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId(taskId));
  }

  /// Отменяет все уведомления (например, при выходе из семьи).
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// Стабильный id уведомления для задачи.
  static int _notificationId(String taskId) {
    return taskId.hashCode & 0x7fffffff;
  }
}
