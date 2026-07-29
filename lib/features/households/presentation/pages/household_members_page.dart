import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';
import 'package:family_planner/features/households/presentation/widgets/member_tile.dart';

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
        householdRepository: repository,
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

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

    final cubit = context.read<HouseholdMembersCubit>();
    final succeeded = await cubit.leaveHousehold(householdId: widget.householdId);

    if (!succeeded || !mounted) return;

    final householdCubit = context.read<HouseholdCubit>();
    await householdCubit.refresh();

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

    final cubit = context.read<HouseholdMembersCubit>();

    final success = await cubit.removeMember(
      householdId: widget.householdId,
      profileId: member.profileId,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить участника.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Участники: ${widget.householdName}'),
      ),
      body: BlocConsumer<HouseholdMembersCubit, HouseholdMembersState>(
        listener: (context, state) {
          if (state is HouseholdInvitationSent) {
            _emailController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Приглашение отправлено.')),
            );
          }

          if (state case HouseholdMembersFailure(:final message)) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
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

          final currentMember =
              members.where((m) => m.profileId == widget.currentMemberId);
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_add_alt_1_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Пригласить участника',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Укажите email зарегистрированного пользователя. '
                          'Он увидит приглашение и сам подтвердит вступление.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key(
                                    'household_invitation_email_field',
                                  ),
                                  controller: _emailController,
                                  enabled: !isSending,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Email участника',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';

                                    if (email.isEmpty) {
                                      return 'Введите email.';
                                    }

                                    final emailRegex = RegExp(
                                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                    );

                                    if (!emailRegex.hasMatch(email)) {
                                      return 'Введите корректный email.';
                                    }

                                    return null;
                                  },
                                  onFieldSubmitted: (_) {
                                    if (!isSending) _sendInvitation();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                key: const Key(
                                  'send_household_invitation_button',
                                ),
                                onPressed:
                                    isSending ? null : _sendInvitation,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Участники (${members.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...members.map(
                  (member) => MemberTile(
                    member: member,
                    isOwner: isOwner,
                    isCurrentUser:
                        member.profileId == widget.currentMemberId,
                    onRemove: () => _removeMember(member),
                  ),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 24),
                  SafeArea(
                    child: OutlinedButton.icon(
                      onPressed: _leaveHousehold,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Выйти из семьи'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
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
