import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/leave_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/remove_household_member_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';

final class HouseholdMembersPage extends StatelessWidget {
  const HouseholdMembersPage({
    required this.householdId,
    required this.householdName,
    required this.currentMemberId,
    super.key,
  });

  final String householdId;
  final String householdName;
  final String currentMemberId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<HouseholdRepository>();

    return BlocProvider(
      create: (_) => HouseholdMembersCubit(
        getHouseholdMembersUseCase: GetHouseholdMembersUseCase(
          repository: repository,
        ),
        createHouseholdInvitationUseCase: CreateHouseholdInvitationUseCase(
          repository: repository,
        ),
        leaveHouseholdUseCase: LeaveHouseholdUseCase(
          repository: repository,
        ),
        removeHouseholdMemberUseCase: RemoveHouseholdMemberUseCase(
          repository: repository,
        ),
      )..load(householdId: householdId),
      child: _HouseholdMembersView(
        householdId: householdId,
        householdName: householdName,
        currentMemberId: currentMemberId,
      ),
    );
  }
}

final class _HouseholdMembersView extends StatefulWidget {
  const _HouseholdMembersView({
    required this.householdId,
    required this.householdName,
    required this.currentMemberId,
  });

  final String householdId;
  final String householdName;
  final String currentMemberId;

  @override
  State<_HouseholdMembersView> createState() => _HouseholdMembersViewState();
}

final class _HouseholdMembersViewState extends State<_HouseholdMembersView> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendInvitation() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    context.read<HouseholdMembersCubit>().inviteByEmail(
      householdId: widget.householdId,
      email: _emailController.text,
    );
  }

  Future<void> _leaveHousehold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из семьи?'),
        content: Text(
          'Вы перестанете быть участником семьи «${widget.householdName}».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final membersCubit = context.read<HouseholdMembersCubit>();
    final householdCubit = context.read<HouseholdCubit>();

    await membersCubit.leaveHousehold(householdId: widget.householdId);

    if (!mounted) return;

    await householdCubit.load();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _removeMember(HouseholdMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text(
          'Удалить «${member.displayName}» из семьи?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final membersCubit = context.read<HouseholdMembersCubit>();
    await membersCubit.removeMember(
      householdId: widget.householdId,
      profileId: member.profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Участники: ${widget.householdName}')),
      body: BlocConsumer<HouseholdMembersCubit, HouseholdMembersState>(
        listener: (context, state) {
          if (state is HouseholdInvitationSent) {
            _emailController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Приглашение отправлено.')),
            );
          }

          if (state case HouseholdMembersFailure(:final message)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          final members = switch (state) {
            HouseholdMembersLoaded(:final members) => members,
            HouseholdInvitationSending(:final members) => members,
            HouseholdInvitationSent(:final members) => members,
            _ => const [],
          };

          final isLoading = state is HouseholdMembersLoading;
          final isSending = state is HouseholdInvitationSending;

          final currentMember = members.where(
            (m) => m.profileId == widget.currentMemberId,
          );
          final isOwner = currentMember.any((m) => m.isOwner);

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HouseholdMembersFailure && members.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: () {
                  context.read<HouseholdMembersCubit>().load(
                    householdId: widget.householdId,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () {
              return context.read<HouseholdMembersCubit>().load(
                householdId: widget.householdId,
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isOwner) ...[
                  Text(
                    'Пригласить участника',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Укажите email зарегистрированного пользователя. '
                    'Он увидит приглашение и сам подтвердит вступление.',
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const Key('household_invitation_email_field'),
                            controller: _emailController,
                            enabled: !isSending,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email участника',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty || !email.contains('@')) {
                                return 'Введите корректный email.';
                              }

                              return null;
                            },
                            onFieldSubmitted: (_) {
                              if (!isSending) {
                                _sendInvitation();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          key: const Key('send_household_invitation_button'),
                          onPressed: isSending ? null : _sendInvitation,
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Пригласить'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                Text(
                  'Участники (${members.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...members.map(
                  (member) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.displayName.isEmpty
                              ? '?'
                              : member.displayName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(member.displayName),
                      subtitle: Text(
                        member.isOwner ? 'Владелец семьи' : 'Участник',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (member.isOwner)
                            const Icon(Icons.workspace_premium_outlined)
                          else ...[
                            const Icon(Icons.person_outline),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Удалить участника',
                                onPressed: () => _removeMember(member),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 32),
                  SafeArea(
                    child: OutlinedButton.icon(
                      onPressed: _leaveHousehold,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Выйти из семьи'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
