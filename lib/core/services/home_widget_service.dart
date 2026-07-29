import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'package:family_planner/features/tasks/tasks.dart';
import '../logging/app_logger.dart';

const String _androidWidgetName = 'TasksWidgetProvider';

bool get _isSupportedPlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Вызывается в фоновом изоляте при нажатии на задачу в виджете.
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
        // Конфигурация Supabase из SharedPreferences (надёжнее в фоне)
        String? supabaseUrl =
            await HomeWidget.getWidgetData<String>('supabase_url');
        String? supabaseKey =
            await HomeWidget.getWidgetData<String>('supabase_key');

        // Резерв: dotenv (если SharedPreferences ещё не сохранили)
        if (supabaseUrl == null || supabaseKey == null) {
          try {
            await dotenv.load(fileName: '.env');
            supabaseUrl = SupabaseConfig.url;
            supabaseKey = SupabaseConfig.publishableKey;
          } catch (_) {
            AppLogger.warning('widget bg: не удалось загрузить .env');
          }
        }

        if (supabaseUrl == null ||
            supabaseUrl.isEmpty ||
            supabaseKey == null ||
            supabaseKey.isEmpty) {
          AppLogger.error('widget bg: нет конфигурации Supabase');
          return;
        }

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        );

        final client = Supabase.instance.client;

        // Восстанавливаем сессию из сохранённого JSON
        final sessionJson =
            await HomeWidget.getWidgetData<String>('supabase_session_json');
        if (sessionJson != null && sessionJson.isNotEmpty) {
          try {
            await client.auth.recoverSession(sessionJson);
          } catch (e) {
            AppLogger.warning('widget bg: не удалось восстановить сессию: $e');
          }
        }

        final isCompleted = currentStatus == 'completed';

        if (isCompleted) {
          // Отмена выполнения — assigned_member_id не трогаем
          await client.from('task_occurrences').update({
            'status': 'pending',
            'completed_by_member_id': null,
            'completed_at': null,
          }).eq('id', taskId);
        } else {
          // Выполнение задачи
          await client.from('task_occurrences').update({
            'status': 'completed',
            'completed_by_member_id': memberId,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'assigned_member_id': memberId,
          }).eq('id', taskId);
        }

        // Обновляем данные виджета
        if (householdId != null) {
          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          final rows = await client
              .from('task_occurrences')
              .select('id, title, status, assigned_member_id')
              .eq('household_id', householdId)
              .eq('planned_for', dateStr);

          final myTasks = rows
              .where((row) => row['assigned_member_id'] == memberId)
              .map((row) {
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
    if (!_isSupportedPlatform) return;

    try {
      await HomeWidget.registerInteractivityCallback(interactiveCallback);

      // Сохраняем конфигурацию для фонового коллбэка
      await HomeWidget.saveWidgetData('supabase_url', SupabaseConfig.url);
      await HomeWidget.saveWidgetData('supabase_key', SupabaseConfig.publishableKey);

      // Сохраняем сессию для фонового коллбэка
      await _saveSession();

      // Слушаем обновления сессии
      Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
        if (authState.session != null) {
          _saveSessionFromSession(authState.session!);
        }
      });
    } on MissingPluginException catch (e) {
      AppLogger.warning('HomeWidget плагин недоступен в данной сборке: $e');
    } catch (e) {
      AppLogger.warning('Не удалось инициализировать HomeWidget: $e');
    }
  }

  static Future<void> syncTasks(List<Task> tasks, String currentMemberId, String householdId) async {
    if (!_isSupportedPlatform) return;

    try {
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

      await _saveSession();

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      AppLogger.warning('syncTasks: ошибка — $e');
    }
  }

  static Future<void> _saveSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _saveSessionFromSession(session);
    } else {
      AppLogger.warning(
        'widget: сессия ещё не восстановлена — '
        'токен сохранится при первой синхронизации задач',
      );
    }
  }

  static Future<void> _saveSessionFromSession(Session session) async {
    await HomeWidget.saveWidgetData(
      'supabase_session_json',
      jsonEncode(session.toJson()),
    );
  }
}
