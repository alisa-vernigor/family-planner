import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../logging/app_logger.dart';

const String _androidWidgetName = 'TasksWidgetProvider';

// Этот метод вызывается в фоновом изоляте, когда пользователь нажимает на задачу в виджете.
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  if (uri.host == 'task' && uri.path == '/toggle') {
    final taskId = uri.queryParameters['id'];
    final currentStatus = uri.queryParameters['status'];
    final householdId = uri.queryParameters['householdId'];
    final memberId = uri.queryParameters['memberId'];

    if (taskId != null && memberId != null) {
      try {
        // Инициализируем окружение в фоновом процессе
        await dotenv.load(fileName: '.env');
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );

        final client = Supabase.instance.client;
        final isCompleted = currentStatus == 'completed';
        final newStatus = isCompleted ? 'pending' : 'completed';

        // Обновляем статус задачи
        await client.from('task_occurrences').update({
          'status': newStatus,
          'completed_by_member_id': isCompleted ? null : memberId,
          'completed_at': isCompleted ? null : DateTime.now().toUtc().toIso8601String(),
          'assigned_member_id': memberId,
        }).eq('id', taskId);

        // Получаем свежие данные для обновления виджета
        if (householdId != null) {
          final now = DateTime.now();
          final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          final rows = await client
              .from('task_occurrences')
              .select('id, title, status, assigned_member_id')
              .eq('household_id', householdId)
              .eq('planned_for', dateStr);

          final myTasks = rows.where((row) => row['assigned_member_id'] == memberId).map((row) {
            return {
              'id': row['id'],
              'title': row['title'],
              'isCompleted': row['status'] == 'completed',
              'householdId': householdId,
              'memberId': memberId,
            };
          }).toList();

          await HomeWidget.saveWidgetData('today_tasks', jsonEncode(myTasks));
          await HomeWidget.updateWidget(androidName: _androidWidgetName);
        }
      } catch (e) {
        AppLogger.error('Ошибка обновления задачи из виджета: $e');
      }
    }
  }
}

final class HomeWidgetService {
  static Future<void> initialize() async {
    await HomeWidget.registerInteractivityCallback(interactiveCallback);
  }

  static Future<void> syncTasks(List<Task> tasks, String currentMemberId, String householdId) async {
    // Выбираем только задачи назначенного пользователя на сегодня
    final myTasks = tasks
        .where((t) => t.assignedMemberId == currentMemberId)
        .map((t) => {
              'id': t.id,
              'title': t.title,
              'isCompleted': t.isCompleted,
              'householdId': householdId,
              'memberId': currentMemberId,
            })
        .toList();

    await HomeWidget.saveWidgetData('today_tasks', jsonEncode(myTasks));
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
}