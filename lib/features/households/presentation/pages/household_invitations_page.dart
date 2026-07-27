import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';

final class HouseholdInvitationsPage extends StatefulWidget {
  const HouseholdInvitationsPage({super.key});

  @override
  State<HouseholdInvitationsPage> createState() =>
      _HouseholdInvitationsPageState();
}

final class _HouseholdInvitationsPageState
    extends State<HouseholdInvitationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<HouseholdInvitationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Приглашения')),
      body: BlocConsumer<HouseholdInvitationsCubit, HouseholdInvitationsState>(
        listener: (context, state) {
          if (state case HouseholdInvitationsFailure(:final message)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          switch (state) {
            case HouseholdInvitationsInitial():
            case HouseholdInvitationsLoading():
              return const Center(child: CircularProgressIndicator());

            case HouseholdInvitationsFailure():
              return Center(
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<HouseholdInvitationsCubit>().load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              );

            case HouseholdInvitationsLoaded(:final invitations):
              return _InvitationsList(
                invitations: invitations,
                actionInvitationId: null,
              );

            case HouseholdInvitationActionInProgress(
              :final invitations,
              :final invitationId,
            ):
              return _InvitationsList(
                invitations: invitations,
                actionInvitationId: invitationId,
              );
          }
        },
      ),
    );
  }
}

final class _InvitationsList extends StatelessWidget {
  const _InvitationsList({
    required this.invitations,
    required this.actionInvitationId,
  });

  final List<HouseholdInvitation> invitations;
  final String? actionInvitationId;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<HouseholdInvitationsCubit>().load(),
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Icon(Icons.mark_email_read_outlined, size: 64),
            SizedBox(height: 16),
            Center(child: Text('Новых приглашений нет.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<HouseholdInvitationsCubit>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: invitations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final invitation = invitations[index];
          final isWorking = actionInvitationId == invitation.id;
          final isExpired = invitation.expiresAt.isBefore(DateTime.now());

          return Opacity(
            opacity: isExpired ? 0.5 : 1,
            child: Card(
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation.householdName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${invitation.invitedByDisplayName} приглашает вас '
                    'в эту семью.',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isExpired
                        ? 'Срок действия истёк'
                        : 'Действует до ${_formatDate(invitation.expiresAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isExpired
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isExpired)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isWorking
                                ? null
                                : () => _decline(context, invitation),
                            child: const Text('Отклонить'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isWorking
                                ? null
                                : () => _accept(context, invitation),
                            child: isWorking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Принять'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    HouseholdInvitation invitation,
  ) async {
    final householdId = await context.read<HouseholdInvitationsCubit>().accept(
      invitation: invitation,
    );

    if (!context.mounted || householdId == null) {
      return;
    }

    await context.read<HouseholdCubit>().load();

    if (!context.mounted) {
      return;
    }

    // SnackBar перед pop — успеет показаться
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          'Вы присоединились к семье «${invitation.householdName}».',
        ),
      ),
    );

    // Небольшая задержка, чтобы SnackBar успел показаться
    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return;
    Navigator.of(context).pop(householdId);
  }

  Future<void> _decline(
    BuildContext context,
    HouseholdInvitation invitation,
  ) async {
    await context.read<HouseholdInvitationsCubit>().decline(
      invitation: invitation,
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day.$month.${value.year}';
  }
}
