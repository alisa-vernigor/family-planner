import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';

final class HouseholdMembersPage extends StatelessWidget {
  const HouseholdMembersPage({
    required this.householdId,
    required this.householdName,
    super.key,
  });

  final String householdId;
  final String householdName;

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
      )..load(householdId: householdId),
      child: _HouseholdMembersView(
        householdId: householdId,
        householdName: householdName,
      ),
    );
  }
}

final class _HouseholdMembersView extends StatefulWidget {
  const _HouseholdMembersView({
    required this.householdId,
    required this.householdName,
  });

  final String householdId;
  final String householdName;

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
                      trailing: Icon(
                        member.isOwner
                            ? Icons.workspace_premium_outlined
                            : Icons.person_outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
