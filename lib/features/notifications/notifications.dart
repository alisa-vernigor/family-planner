/// Notifications feature — центр уведомлений / inbox.
///
/// Собирает ленту активности из существующих данных:
/// `task_occurrences` + `household_invitations` (никаких новых таблиц/RPC).
library;

export 'data/notification_read_store.dart';
export 'data/repositories/supabase_notifications_repository.dart';
export 'domain/entities/notification_item.dart';
export 'domain/repositories/notifications_repository.dart';
