import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
                              if (!isLoading) _create();
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
          ),
        );
      },
    );
  }
}
