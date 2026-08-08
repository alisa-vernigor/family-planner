import 'package:equatable/equatable.dart';

import '../../domain/entities/notification_item.dart';

sealed class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => const [];
}

final class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

final class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({required this.items, required this.readIds});

  final List<NotificationItem> items;

  /// Ключи прочитанных уведомлений (см. `NotificationReadStore`).
  final Set<String> readIds;

  int get unreadCount =>
      items.where((item) => !readIds.contains(item.id)).length;

  bool isRead(NotificationItem item) => readIds.contains(item.id);

  @override
  List<Object?> get props => [items, readIds];
}

final class NotificationsFailure extends NotificationsState {
  const NotificationsFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
