import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel,
        RealtimeSubscribeStatus;

import '../logging/app_logger.dart';

/// Mixin for [State] widgets that subscribe to realtime changes on the
/// `task_occurrences` table.
///
/// Упрощение для нейронок: одна реализация вместо дублирования в
/// [TodayPage] и [ScheduledPage].
mixin RealtimeTasksSubscriptionMixin<S extends StatefulWidget> on State<S> {
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;

  /// Начинает слушать изменения в `task_occurrences` для [householdId].
  ///
  /// [channelPrefix] — уникальный префикс для имени канала
  /// (например, `'task-occurrences'` или `'scheduled-tasks'`).
  ///
  /// [onChanged] вызывается после дебаунса 1.5с при любом событии
  /// (INSERT / UPDATE / DELETE) в таблице.
  void subscribeToTaskChanges({
    required String householdId,
    required String channelPrefix,
    required VoidCallback onChanged,
  }) {
    _realtimeChannel = Supabase.instance.client
        .channel('$channelPrefix-$householdId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_occurrences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'household_id',
            value: householdId,
          ),
          callback: (_) {
            if (!mounted) return;

            // Debounce — события realtime сыплются пачкой при батч-операциях.
            // Ждём тишины 1.5с перед релоадом.
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(
              const Duration(milliseconds: 1500),
              () {
                if (mounted) onChanged();
              },
            );
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            AppLogger.error('Realtime error', error: error);
          }

          if (status == RealtimeSubscribeStatus.subscribed) {
            AppLogger.debug('Realtime канал подключён');
          }
        });
  }

  /// Пересоздаёт подписку при смене household.
  void reattachTaskSubscription({
    required String oldHouseholdId,
    required String newHouseholdId,
    required String channelPrefix,
    required VoidCallback onChanged,
  }) {
    if (oldHouseholdId == newHouseholdId) return;
    unsubscribeFromTaskChanges();
    subscribeToTaskChanges(
      householdId: newHouseholdId,
      channelPrefix: channelPrefix,
      onChanged: onChanged,
    );
  }

  /// Отписывается от канала.
  void unsubscribeFromTaskChanges() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }
}
