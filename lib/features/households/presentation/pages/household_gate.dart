import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/today/presentation/pages/today_page.dart';
import 'package:family_planner/features/scheduled/presentation/pages/scheduled_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';

final class HouseholdGate extends StatefulWidget {
  const HouseholdGate({required this.currentMemberId, super.key});

  final String currentMemberId;

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

final class _HouseholdGateState extends State<HouseholdGate> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    context.read<HouseholdCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HouseholdCubit, HouseholdState>(
      builder: (context, state) {
        switch (state) {
          case HouseholdInitial():
          case HouseholdLoading():
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case HouseholdEmpty():
            return const CreateHouseholdPage();

          case HouseholdFailure(:final message):
            return Scaffold(
              appBar: AppBar(title: const Text('Семья')),
              body: Center(
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
                        onPressed: () {
                          context.read<HouseholdCubit>().load();
                        },
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            );

          case HouseholdLoaded(:final households):
            return _AppShell(
              households: households,
              currentMemberId: widget.currentMemberId,
              currentTab: _currentTab,
              onTabChanged: (index) {
                setState(() => _currentTab = index);
              },
            );
        }
      },
    );
  }
}

final class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.households,
    required this.currentMemberId,
    required this.currentTab,
    required this.onTabChanged,
  });

  final List<Household> households;
  final String currentMemberId;
  final int currentTab;
  final ValueChanged<int> onTabChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<_AppShell> {
  late String _selectedHouseholdId;

  @override
  void initState() {
    super.initState();
    _selectedHouseholdId = widget.households.first.id;
    context.read<HouseholdInvitationsCubit>().load();
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final exists =
        widget.households.any((h) => h.id == _selectedHouseholdId);

    if (!exists) {
      _selectedHouseholdId = widget.households.first.id;
    }
  }

  Household get _selectedHousehold {
    return widget.households.firstWhere(
      (h) => h.id == _selectedHouseholdId,
    );
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
    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedHouseholdId,
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
              setState(() => _selectedHouseholdId = householdId);
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Участники',
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseholdMembersPage(
                    householdId: _selectedHousehold.id,
                    householdName: _selectedHousehold.name,
                    currentMemberId: widget.currentMemberId,
                  ),
                ),
              ).then((_) {
                if (context.mounted) {
                  context.read<HouseholdCubit>().refresh();
                }
              });
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

              if (!context.mounted) return;
              context.read<HouseholdCubit>().refresh();
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
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: widget.currentTab,
        children: [
          TodayPage(
            householdId: _selectedHousehold.id,
            householdName: _selectedHousehold.name,
            currentMemberId: widget.currentMemberId,
          ),
          ScheduledPage(
            householdId: _selectedHousehold.id,
            currentMemberId: widget.currentMemberId,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentTab,
        onDestinationSelected: widget.onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Сегодня',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Запланированные',
          ),
        ],
      ),
    );
  }
}
