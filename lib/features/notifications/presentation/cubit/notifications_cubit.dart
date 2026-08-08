import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';

import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../data/notification_read_store.dart';

import 'notifications_state.dart';

final class AppNotificationsCubit extends Cubit<NotificationsState> {
  AppNotificationsCubit({
    required this.notificationsRepository,
    required this.readStore,
    this.notifications,
  }) : super(NotificationsInitial()) {
    if (notifications != null) {
      emit(NotificationsLoaded(items: notifications!, readIds: const {}));
    }
  }

  final NotificationsRepository notificationsRepository;
  final NotificationReadStore readStore;

  /// Инъектируемый список (для тестов/превью) — заменяет загрузку с сервера.
  final List<NotificationItem>? notifications;

  Future<void> load({String? householdId}) async {
    emit(const NotificationsLoading());

    try {
      final items = await notificationsRepository.getActivityFeed(
        householdId: householdId,
      );
      final readIds = await readStore.loadReadIds();

      AppLogger.info('Уведомления загружены: ${items.length}');

      emit(NotificationsLoaded(items: items, readIds: readIds));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось загрузить уведомления.',
      );
    }
  }

  /// Обновляет ленту, сохраняя read-статус (для pull-to-refresh / realtime).
  Future<void> refresh({String? householdId}) async {
    try {
      final items = await notificationsRepository.getActivityFeed(
        householdId: householdId,
      );
      // Read-статус всегда читаем из стора: markAllRead уже туда сохранил,
      // поэтому он — надмножество того, что было в state.
      final readIds = await readStore.loadReadIds();

      emit(NotificationsLoaded(items: items, readIds: readIds));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось обновить уведомления.',
      );
    }
  }

  Future<void> markAllRead() async {
    final current = switch (state) {
      NotificationsLoaded(:final items, :final readIds) => (items, readIds),
      _ => (const <NotificationItem>[], const <String>{}),
    };
    final (items, readIds) = current;

    await notificationsRepository.markAllRead();
    final allIds = items.map((item) => item.id).toList(growable: false);
    await readStore.markAllRead(allIds);

    final merged = {...readIds, ...allIds};
    emit(NotificationsLoaded(items: items, readIds: merged));
  }

  /// Убирает из ленты событие (например, после принятия/отклонения приглашения).
  void removeItem(String id) {
    final current = switch (state) {
      NotificationsLoaded(:final items, :final readIds) => (items, readIds),
      _ => (const <NotificationItem>[], const <String>{}),
    };
    final (items, readIds) = current;

    emit(
      NotificationsLoaded(
        items: items.where((item) => item.id != id).toList(growable: false),
        readIds: readIds,
      ),
    );
  }

  int get unreadCount {
    return switch (state) {
      NotificationsLoaded(:final items, :final readIds) =>
        items.where((item) => !readIds.contains(item.id)).length,
      _ => 0,
    };
  }

  void _emitFailure({
    required Object exception,
    required StackTrace stackTrace,
    required String message,
  }) {
    AppLogger.error(message, error: exception, stackTrace: stackTrace);
    emit(NotificationsFailure(message: message));
  }
}
