import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/households/presentation/pages/create_household_page.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';

/// Экран, отображаемый когда у пользователя нет семей.
///
/// Показывает приглашения (если есть) или форму создания семьи.
final class EmptyShell extends StatefulWidget {
  const EmptyShell({required this.currentMemberId, super.key});

  final String currentMemberId;

  @override
  State<EmptyShell> createState() => _EmptyShellState();
}

final class _EmptyShellState extends State<EmptyShell> {
  @override
  void initState() {
    super.initState();
    context.read<HouseholdInvitationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Семья'),
        actions: [
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
            onPressed: _openInvitations,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (value) {
              if (value == 'signout') {
                context.read<AuthCubit>().signOut();
              }
            },
            itemBuilder: (context) => [
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
      body: BlocBuilder<HouseholdInvitationsCubit, HouseholdInvitationsState>(
        builder: (context, state) {
          if (state is HouseholdInvitationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final invitations = switch (state) {
            HouseholdInvitationsLoaded(:final invitations) => invitations,
            _ => <HouseholdInvitation>[],
          };

          if (invitations.isNotEmpty) {
            return const InvitationsPrompt();
          }

          return const CreateHouseholdPage();
        },
      ),
    );
  }

  void _openInvitations() async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const HouseholdInvitationsPage(),
      ),
    );

    if (!context.mounted) return;
    context.read<HouseholdCubit>().load();
  }
}

/// Приглашения есть — предложить посмотреть или создать семью.
final class InvitationsPrompt extends StatelessWidget {
  const InvitationsPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Вас пригласили в семью',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'У вас есть приглашения. Посмотрите их или создайте свою семью.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const HouseholdInvitationsPage(),
                  ),
                );
                if (!context.mounted) return;
                context.read<HouseholdCubit>().load();
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('Посмотреть приглашения'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const CreateHouseholdPage(closeAfterCreate: true),
                  ),
                );
                if (!context.mounted) return;
                context.read<HouseholdCubit>().load();
              },
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Создать свою семью'),
            ),
          ],
        ),
      ),
    );
  }
}
