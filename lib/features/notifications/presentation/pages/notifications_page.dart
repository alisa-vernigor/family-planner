import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/notifications/notifications.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:family_planner/features/tasks/tasks.dart';

final class NotificationsPage extends StatelessWidget {
  const NotificationsPage({required this.currentMemberId, super.key});

  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    // AppNotificationsCubit предоставляется на уровне AppShell (BlocProvider),
    // чтобы бейдж в NavigationBar видел unreadCount. Экран лишь подписывается.
    return _NotificationsView(currentMemberId: currentMemberId);
  }
}

final class _NotificationsView extends StatefulWidget {
  const _NotificationsView({required this.currentMemberId});

  final String currentMemberId;

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

final class _NotificationsViewState extends State<_NotificationsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          BlocBuilder<AppNotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state case NotificationsLoaded(:final items, :final readIds)
                  when items.any((item) => !readIds.contains(item.id))) {
                return TextButton.icon(
                  onPressed: () =>
                      context.read<AppNotificationsCubit>().markAllRead(),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Прочитать всё'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<AppNotificationsCubit, NotificationsState>(
        builder: (context, state) {
          switch (state) {
            case NotificationsInitial():
            case NotificationsLoading():
              return const Center(child: CircularProgressIndicator());

            case NotificationsFailure(:final message):
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            context.read<AppNotificationsCubit>().load(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );

            case NotificationsLoaded(:final items, :final readIds):
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async =>
                      context.read<AppNotificationsCubit>().refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 160),
                      Icon(Icons.notifications_none, size: 64),
                      SizedBox(height: 16),
                      Center(child: Text('Пока нет уведомлений.')),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    context.read<AppNotificationsCubit>().refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationCard(
                      item: item,
                      isRead: readIds.contains(item.id),
                      currentMemberId: widget.currentMemberId,
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

final class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isRead,
    required this.currentMemberId,
  });

  final NotificationItem item;
  final bool isRead;
  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      NotificationKind.taskAssigned => Icons.person_add_alt_1_outlined,
      NotificationKind.taskCompleted => Icons.check_circle_outline,
      NotificationKind.taskSkipped => Icons.skip_next_outlined,
      NotificationKind.invitation => Icons.mail_outline,
    };

    return Card(
      color: isRead ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? Colors.transparent
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(item.occurredAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (item.isInvitation)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _InvitationActions(item: item),
                      ),
                  ],
                ),
              ),
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (item.isInvitation) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HouseholdInvitationsPage()),
      );
      return;
    }

    final taskId = item.taskId;
    if (taskId == null) return;

    final repository = context.read<TaskRepository>();
    try {
      final all = await repository.getAllPending(householdId: item.householdId ?? '');
      Task? task;
      for (final t in all) {
        if (t.id == taskId) {
          task = t;
          break;
        }
      }
      if (task != null && context.mounted) {
        await showEditTaskSheet(context: context, task: task);
      }
    } catch (exception, stackTrace) {
      AppLogger.error('Не удалось открыть задачу из уведомления',
          error: exception, stackTrace: stackTrace);
    }
  }

  String _relativeTime(DateTime occurredAt) {
    final diff = DateTime.now().difference(occurredAt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${occurredAt.day.toString().padLeft(2, '0')}.'
        '${occurredAt.month.toString().padLeft(2, '0')}.${occurredAt.year}';
  }
}

final class _InvitationActions extends StatelessWidget {
  const _InvitationActions({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final isPending = item.invitationStatus == 'pending';
    if (!isPending) {
      final label = item.invitationStatus == 'accepted'
          ? 'Приглашение принято'
          : 'Приглашение отклонено';
      return Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _decline(context),
            child: const Text('Отклонить'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => _accept(context),
            child: const Text('Принять'),
          ),
        ),
      ],
    );
  }

  Future<void> _accept(BuildContext context) async {
    final invitationId = item.invitationId;
    if (invitationId == null) return;

    final invitation = HouseholdInvitation(
      id: invitationId,
      householdId: item.householdId ?? '',
      householdName: '',
      invitedByDisplayName: item.actorName,
      createdAt: item.occurredAt,
      expiresAt: item.occurredAt.add(const Duration(days: 7)),
    );

    final householdId =
        await context.read<HouseholdInvitationsCubit>().accept(
              invitation: invitation,
            );

    if (householdId == null || !context.mounted) return;

    await context.read<HouseholdCubit>().load();
    if (!context.mounted) return;
    context.read<AppNotificationsCubit>().removeItem(item.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вы присоединились к семье.')),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final invitationId = item.invitationId;
    if (invitationId == null) return;

    final invitation = HouseholdInvitation(
      id: invitationId,
      householdId: item.householdId ?? '',
      householdName: '',
      invitedByDisplayName: item.actorName,
      createdAt: item.occurredAt,
      expiresAt: item.occurredAt.add(const Duration(days: 7)),
    );

    await context.read<HouseholdInvitationsCubit>().decline(
          invitation: invitation,
        );

    if (!context.mounted) return;
    context.read<AppNotificationsCubit>().removeItem(item.id);
  }
}
