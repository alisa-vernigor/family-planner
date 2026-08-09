import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/core/sync/sync_state.dart';

/// A Material banner that shows when the app is offline or syncing.
///
/// Place in [Scaffold] or as an overlay in the app shell.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncCubitState>(
      builder: (context, state) {
        if (state.isOnline && state.status is SyncSynced) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: state.isOnline
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(
                state.isOnline ? Icons.sync : Icons.cloud_off,
                size: 20,
                color: state.isOnline
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _message(state),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.status is SyncSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!state.isOnline)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Изменения будут синхронизированы при подключении к интернету.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: const Text('Ок'),
                ),
            ],
          ),
        );
      },
    );
  }

  String _message(SyncCubitState state) {
    if (!state.isOnline) {
      return 'Нет подключения к интернету. '
          'Изменения будут синхронизированы позже.';
    }
    return switch (state.status) {
      SyncSyncing() => 'Синхронизация...',
      SyncPending(:final count) =>
        'Ожидает синхронизации: $count операций',
      SyncError(:final message) => message,
      _ => '',
    };
  }
}
