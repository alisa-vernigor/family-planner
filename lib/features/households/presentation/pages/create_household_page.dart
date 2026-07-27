import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';

final class CreateHouseholdPage extends StatefulWidget {
  const CreateHouseholdPage({this.closeAfterCreate = false, super.key});

  final bool closeAfterCreate;

  @override
  State<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

final class _CreateHouseholdPageState extends State<CreateHouseholdPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _errorMessage = null;
    context.read<HouseholdCubit>().create(name: _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HouseholdCubit, HouseholdState>(
      listener: (context, state) {
        if (state is HouseholdLoaded) {
          if (widget.closeAfterCreate) {
            Navigator.of(context).pop();
          }
          return;
        }

        if (state is HouseholdFailure) {
          setState(() => _errorMessage = state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is HouseholdLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Создайте семью'),
            leading: widget.closeAfterCreate
                ? null
                : IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Выйти из аккаунта',
                    onPressed: () => context.read<AuthCubit>().signOut(),
                  ),
          ),
          body: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
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
                            'Семья — это группа, в которой вы будете '
                            'создавать и распределять задачи.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
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
                              if (!isLoading) _create();
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: isLoading ? null : _create,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                          if (!widget.closeAfterCreate) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed:
                                  isLoading ? null : _showSkipInfo,
                              child: const Text(
                                'Что такое семья и зачем она нужна?',
                              ),
                            ),
                          ],
                        ],
                      ),
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

  void _showSkipInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Зачем нужна семья?'),
        content: const Text(
          'Семья объединяет участников, которые планируют и распределяют '
          'задачи. Вы можете создать семью и пригласить в неё других '
          'пользователей по email.\n\n'
          'После создания семьи вы сможете:\n'
          '• Создавать задачи на каждый день\n'
          '• Назначать ответственных\n'
          '• Автоматически распределять задачи между участниками\n'
          '• Следить за выполнением',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
