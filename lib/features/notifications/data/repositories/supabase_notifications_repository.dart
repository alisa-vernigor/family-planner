import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';

/// Имплементация [NotificationsRepository] через Supabase.
///
/// Лента собирается из уже существующих таблиц (без новых RPC/таблиц):
/// — `task_occurrences`: задачи, назначенные мне другими участниками,
///   и задачи, выполненные/пропущенные другими участниками;
/// — `household_invitations`: приглашения в семьи.
///
/// Read-статус хранится локально (см. Drift-кэш), поэтому «прочитать все»
/// на сервере нечего — `markAllRead` здесь no-op.
final class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static const int _feedWindowDays = 30;

  @override
  Future<List<NotificationItem>> getActivityFeed({String? householdId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const NotificationsNotAuthenticatedException();
    }

    final items = <NotificationItem>[];

    final taskRows = await _client
        .from('task_occurrences')
        .select(
          'id, household_id, title, status, created_at, completed_at, '
          'updated_at, planned_for, assigned_member_id, '
          'profiles!task_occurrences_created_by_fkey(display_name)',
        )
        .gte('updated_at', _iso(_nowUtc().subtract(const Duration(days: _feedWindowDays))))
        .order('updated_at', ascending: false)
        .limit(200);

    for (final row in taskRows) {
      items.addAll(_taskItems(row, currentUserId));
    }

    final invitationRows = await _client
        .from('household_invitations')
        .select(
          'id, household_id, status, created_at, expires_at, '
          'invited_by_profile_id, '
          'profiles!household_invitations_invited_by_profile_id_fkey('
          'display_name'
          ')',
        )
        .eq('invited_profile_id', currentUserId)
        .gte('created_at', _iso(_nowUtc().subtract(const Duration(days: _feedWindowDays))))
        .order('created_at', ascending: false)
        .limit(50);

    for (final row in invitationRows) {
      items.add(_invitationItem(row));
    }

    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  /// События по одной строке задачи.
  List<NotificationItem> _taskItems(Map<String, dynamic> row, String currentUserId) {
    final taskId = row['id'] as String;
    final householdId = row['household_id'] as String;
    final title = row['title'] as String;
    final status = row['status'] as String? ?? 'pending';
    final assignedMemberId = row['assigned_member_id'] as String?;
    final createdBy = row['profiles'] as Map<String, dynamic>?;
    final actorName = createdBy?['display_name'] as String? ?? 'Кто-то';
    final actorId = row['created_by'] as String?;

    final items = <NotificationItem>[];

    // 1. Задача назначена мне другим участником.
    if (assignedMemberId == currentUserId &&
        actorId != null &&
        actorId != currentUserId) {
      final occurredAt =
          _parseDateTimeOrNow(row['updated_at']);
      items.add(
        NotificationItem(
          id: 'task:$taskId:assigned',
          kind: NotificationKind.taskAssigned,
          actorId: actorId,
          actorName: actorName,
          title: 'Задача назначена',
          subtitle: '$actorName назначил(а) вам задачу «$title»',
          occurredAt: occurredAt,
          taskId: taskId,
          taskStatus: status,
          householdId: householdId,
        ),
      );
    }

    // 2. Кто-то другой выполнил/пропустил задачу (заметно всей семье).
    final isDoneByOther =
        (status == 'completed' || status == 'skipped') &&
        actorId != null &&
        actorId != currentUserId;
    if (isDoneByOther) {
      final completedAt = row['completed_at'] as String?;
      final updatedAt = row['updated_at'] as String?;
      final occurredAt =
          _parseDateTime(completedAt) ?? _parseDateTimeOrNow(updatedAt);
      final isCompleted = status == 'completed';
      items.add(
        NotificationItem(
          id: 'task:$taskId:${isCompleted ? 'completed' : 'skipped'}',
          kind: isCompleted
              ? NotificationKind.taskCompleted
              : NotificationKind.taskSkipped,
          actorId: actorId,
          actorName: actorName,
          title: isCompleted ? 'Задача выполнена' : 'Задача пропущена',
          subtitle:
              '$actorName ${isCompleted ? 'выполнил(а)' : 'пропустил(а)'} задачу «$title»',
          occurredAt: occurredAt,
          taskId: taskId,
          taskStatus: status,
          householdId: householdId,
        ),
      );
    }

    return items;
  }

  NotificationItem _invitationItem(Map<String, dynamic> row) {
    final inviter = row['profiles'] as Map<String, dynamic>?;
    final invitedBy = inviter?['display_name'] as String? ?? 'Кто-то';

    return NotificationItem(
      id: 'invitation:${row['id']}',
      kind: NotificationKind.invitation,
      actorId: (row['invited_by_profile_id'] as String?) ?? '',
      actorName: invitedBy,
      title: 'Приглашение в семью',
      subtitle: '$invitedBy приглашает вас в свою семью',
      occurredAt: _parseDateTimeOrNow(row['created_at']),
      invitationId: row['id'] as String?,
      invitationStatus: row['status'] as String? ?? 'pending',
      householdId: row['household_id'] as String?,
    );
  }

  @override
  Future<void> markAllRead() async {
    // Read-статус живёт только локально (Drift-кэш) — на сервере хранить нечего.
    AppLogger.debug('NotificationsRepository.markAllRead: no-op на сервере');
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  DateTime _parseDateTimeOrNow(dynamic value) {
    return _parseDateTime(value) ?? _nowUtc();
  }

  DateTime _nowUtc() => DateTime.now().toUtc();

  String _iso(DateTime value) => value.toIso8601String();
}

final class NotificationsNotAuthenticatedException implements Exception {
  const NotificationsNotAuthenticatedException();

  @override
  String toString() {
    return 'NotificationsNotAuthenticatedException: пользователь не авторизован.';
  }
}
