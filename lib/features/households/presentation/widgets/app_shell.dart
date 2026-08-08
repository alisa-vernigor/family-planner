import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' hide Column;

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';
import 'package:family_planner/features/today/presentation/pages/today_page.dart';
import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';
import 'package:family_planner/features/notifications/notifications.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:family_planner/features/notifications/presentation/pages/notifications_page.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/core/widgets/offline_indicator.dart';

/// Основной каркас приложения с навигацией (табы, выбор семьи, меню).
///
/// Содержит AppBar с селектором семьи, кнопками участников/приглашений,
/// IndexedStack для TodayPage + ScheduledPage и NavigationBar.
final class AppShell extends StatefulWidget {
  const AppShell({
    required this.households,
    required this.selectedHouseholdId,
    required this.currentMemberId,
    required this.currentTab,
    required this.onTabChanged,
    required this.onHouseholdChanged,
    super.key,
  });

  final List<Household> households;
  final String selectedHouseholdId;
  final String currentMemberId;
  final int currentTab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onHouseholdChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  String? _lastSyncedHouseholdId;
  late final AppNotificationsCubit _notificationsCubit;

  @override
  void initState() {
    super.initState();
    _notificationsCubit = AppNotificationsCubit(
      notificationsRepository: context.read<NotificationsRepository>(),
      readStore: NotificationReadStore(),
    )..load();
    context.read<HouseholdInvitationsCubit>().load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
  }

  @override
  void dispose() {
    _notificationsCubit.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedHouseholdId != widget.selectedHouseholdId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
    }
  }

  Future<void> _syncIfNeeded() async {
    if (_lastSyncedHouseholdId == widget.selectedHouseholdId) return;
    _lastSyncedHouseholdId = widget.selectedHouseholdId;

    final householdId = widget.selectedHouseholdId;
    final connectivity = context.read<ConnectivityService>();
    final householdRepo = context.read<HouseholdRepository>();

    if (!connectivity.currentOnline) return;

    // On web (no AppDatabase) skip member caching.
    AppDatabase db;
    try {
      db = context.read<AppDatabase>();
    } catch (_) {
      return;
    }

    try {
      // Sync members to local cache
      final members = await householdRepo.getMembers(householdId: householdId);
      final companions = members.map((m) => HouseholdMembersCompanion(
        profileId: Value(m.profileId),
        householdId: Value(householdId),
        displayName: Value(m.displayName),
        avatarUrl: Value(m.avatarUrl),
        role: Value(m.role),
      )).toList();
      await db.householdMembersDao.clearHousehold(householdId);
      if (companions.isNotEmpty) {
        await db.householdMembersDao.upsertMembers(companions);
      }
      AppLogger.info('Cached ${members.length} members for $householdId');
    } catch (e) {
      AppLogger.debug('Member cache sync skipped: $e');
    }
  }

  Household get _selectedHousehold {
    return widget.households.firstWhere(
      (h) => h.id == widget.selectedHouseholdId,
      orElse: () => widget.households.first,
    );
  }

  void _onHouseholdActionDone() {
    context.read<HouseholdCubit>().refresh();
  }

  Future<void> _showRenameDialog(Household household) async {
    final controller = TextEditingController(text: household.name);
    final cubit = context.read<HouseholdCubit>();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать семью'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название семьи',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(ctx).pop(trimmed);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || !context.mounted) return;

    cubit.update(
      householdId: household.id,
      name: name,
    );
  }

  Future<void> _deleteHousehold(Household household) async {
    final cubit = context.read<HouseholdCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить семью?'),
        content: Text(
          'Все данные семьи «${household.name}» будут удалены. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    cubit.delete(householdId: household.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _notificationsCubit,
      child: Scaffold(
        appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.selectedHouseholdId,
            isDense: true,
            items: widget.households
                .map(
                  (h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (householdId) {
              if (householdId == null) return;
              widget.onHouseholdChanged(householdId);
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Участники',
            icon: const Icon(Icons.group_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseholdMembersPage(
                    householdId: _selectedHousehold.id,
                    householdName: _selectedHousehold.name,
                    currentMemberId: widget.currentMemberId,
                  ),
                ),
              );

              _onHouseholdActionDone();
            },
          ),
          IconButton(
            tooltip: 'Приглашения',
            icon: BlocBuilder<HouseholdInvitationsCubit,
                HouseholdInvitationsState>(
              builder: (context, state) {
                final count = switch (state) {
                  HouseholdInvitationsLoaded(:final invitations) =>
                    invitations.length,
                  _ => 0,
                };

                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.mail_outline),
                );
              },
            ),
            onPressed: () async {
              await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const HouseholdInvitationsPage(),
                ),
              );

              _onHouseholdActionDone();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  await _showRenameDialog(_selectedHousehold);
                case 'create':
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreateHouseholdPage(closeAfterCreate: true),
                    ),
                  );
                  if (context.mounted) {
                    context.read<HouseholdCubit>().load();
                  }
                case 'delete':
                  await _deleteHousehold(_selectedHousehold);
                case 'signout':
                  context.read<AuthCubit>().signOut();
                case 'profile':
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsPage(
                        profileId: widget.currentMemberId,
                      ),
                    ),
                  );
                  _onHouseholdActionDone();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Переименовать'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'create',
                child: ListTile(
                  leading: Icon(Icons.add_home_outlined),
                  title: Text('Создать семью'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Удалить семью'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Настройки профиля'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Выйти из аккаунта'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: IndexedStack(
              index: widget.currentTab,
              children: [
                TodayPage(
                  key: ValueKey('today_${_selectedHousehold.id}'),
                  householdId: _selectedHousehold.id,
                  householdName: _selectedHousehold.name,
                  currentMemberId: widget.currentMemberId,
                ),
                ScheduledPage(
                  key: ValueKey('scheduled_${_selectedHousehold.id}'),
                  householdId: _selectedHousehold.id,
                  currentMemberId: widget.currentMemberId,
                ),
                NotificationsPage(currentMemberId: widget.currentMemberId),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentTab,
        onDestinationSelected: (index) {
          // При переключении на таб уведомлений — обновляем ленту,
          // чтобы бейдж и список были свежими.
          if (index == 2) {
            _notificationsCubit.refresh();
          }
          widget.onTabChanged(index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Сегодня',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Запланированные',
          ),
          NavigationDestination(
            icon: BlocBuilder<AppNotificationsCubit, NotificationsState>(
              builder: (context, state) {
                final count = state is NotificationsLoaded
                    ? state.unreadCount
                    : 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                );
              },
            ),
            selectedIcon: BlocBuilder<AppNotificationsCubit, NotificationsState>(
              builder: (context, state) {
                final count = state is NotificationsLoaded
                    ? state.unreadCount
                    : 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications),
                );
              },
            ),
            label: 'Уведомления',
          ),
        ],
      ),
      ),
    );
  }
}
