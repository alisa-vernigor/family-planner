import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

final class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

final class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistration = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<AuthCubit>();

    if (_isRegistration) {
      cubit.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
      );
      return;
    }

    cubit.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _toggleMode() {
    setState(() => _isRegistration = !_isRegistration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    final failureMessage =
                        state is AuthFailure ? state.message : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.family_restroom_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Family Planner',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegistration
                              ? 'Создайте аккаунт для планирования дел семьи'
                              : 'Войдите, чтобы увидеть задачи семьи',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 40),
                        if (failureMessage != null) ...[
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
                                    failureMessage,
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
                        if (_isRegistration) ...[
                          TextFormField(
                            controller: _displayNameController,
                            enabled: !isLoading,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Ваше имя',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите ваше имя.';
                              }

                              if (value.trim().length > 60) {
                                return 'Имя должно быть не длиннее 60 символов.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Введите email.';
                            }

                            if (!email.contains('@')) {
                              return 'Введите корректный email.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !isLoading,
                          obscureText: _obscurePassword,
                          autofillHints: [
                            _isRegistration
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Показать пароль'
                                  : 'Скрыть пароль',
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Пароль должен содержать минимум 8 символов.';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isLoading) _submit();
                          },
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegistration
                                        ? 'Зарегистрироваться'
                                        : 'Войти',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegistration
                                ? 'У меня уже есть аккаунт'
                                : 'Создать новый аккаунт',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
