import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/today/presentation/pages/today_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/households/presentation/pages/household_members_page.dart';

final class HouseholdGate extends StatefulWidget {
  const HouseholdGate({required this.currentMemberId, super.key});

  final String currentMemberId;

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

final class _HouseholdGateState extends State<HouseholdGate> {
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
                      const Icon(Icons.cloud_off_outlined, size: 48),
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
            return _HouseholdSelector(
              households: households,
              currentMemberId: widget.currentMemberId,
            );
        }
      },
    );
  }
}

final class _HouseholdSelector extends StatefulWidget {
  const _HouseholdSelector({
    required this.households,
    required this.currentMemberId,
  });

  final List<Household> households;
  final String currentMemberId;

  @override
  State<_HouseholdSelector> createState() => _HouseholdSelectorState();
}

final class _HouseholdSelectorState extends State<_HouseholdSelector> {
  late String _selectedHouseholdId;

  @override
  void initState() {
    super.initState();
    _selectedHouseholdId = widget.households.first.id;
  }

  @override
  void didUpdateWidget(covariant _HouseholdSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final exists = widget.households.any(
      (household) => household.id == _selectedHouseholdId,
    );

    if (!exists) {
      _selectedHouseholdId = widget.households.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedHousehold = widget.households.firstWhere(
      (household) => household.id == _selectedHouseholdId,
    );

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedHousehold.id,
            items: widget.households
                .map(
                  (household) => DropdownMenuItem(
                    value: household.id,
                    child: Text(household.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (householdId) {
              if (householdId == null) {
                return;
              }

              setState(() {
                _selectedHouseholdId = householdId;
              });
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
                    householdId: selectedHousehold.id,
                    householdName: selectedHousehold.name,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Приглашения',
            icon: const Icon(Icons.mail_outline),
            onPressed: () async {
              await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const HouseholdInvitationsPage(),
                ),
              );

              if (!context.mounted) {
                return;
              }

              context.read<HouseholdCubit>().load();
            },
          ),
          IconButton(
            tooltip: 'Создать семью',
            icon: const Icon(Icons.add_home_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const CreateHouseholdPage(closeAfterCreate: true),
                ),
              );
            },
          ),
        ],
      ),
      body: TodayPage(
        householdId: selectedHousehold.id,
        householdName: selectedHousehold.name,
        currentMemberId: widget.currentMemberId,
      ),
    );
  }
}

final class CreateHouseholdPage extends StatefulWidget {
  const CreateHouseholdPage({this.closeAfterCreate = false, super.key});

  final bool closeAfterCreate;

  @override
  State<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

final class _CreateHouseholdPageState extends State<CreateHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    context.read<HouseholdCubit>().create(name: _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HouseholdCubit, HouseholdState>(
      listener: (context, state) {
        if (widget.closeAfterCreate && state is HouseholdLoaded) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isLoading = state is HouseholdLoading;
        final errorMessage = state is HouseholdFailure ? state.message : null;

        return Scaffold(
          appBar: AppBar(title: const Text('Создайте семью')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Как назвать вашу семью?',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Например: «Семья Ивановых» или «Наша квартира».',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        if (errorMessage != null) ...[
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _nameController,
                          enabled: !isLoading,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Название семьи',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.groups_outlined),
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';

                            if (name.isEmpty) {
                              return 'Введите название семьи.';
                            }

                            if (name.length > 100) {
                              return 'Название должно быть не длиннее 100 символов.';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isLoading) {
                              _create();
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: isLoading ? null : _create,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Создать семью'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
