import '../entities/notification_item.dart';

/// Контракт репозитория центра уведомлений.
abstract interface class NotificationsRepository {
  /// Собирает ленту активности семьи:
  /// — задачи, назначенные текущему пользователю другими участниками;
  /// — задачи, выполненные/пропущенные другими участниками;
  /// — приглашения в семьи.
  ///
  /// [householdId] — семья, по которой собираются события (null — по всем).
  /// Возвращает события, отсортированные по времени (новые сверху).
  Future<List<NotificationItem>> getActivityFeed({String? householdId});

  /// Пометить все уведомления прочитанными.
  ///
  /// Существует только локально: Supabase не хранит read-статус.
  Future<void> markAllRead();
}
