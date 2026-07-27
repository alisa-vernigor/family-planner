import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

final class EmailConfirmationPage extends StatelessWidget {
  const EmailConfirmationPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isFailure = state is AuthFailure;

        return Scaffold(
          appBar: AppBar(title: const Text('Подтвердите email')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFailure ? Icons.error_outline : Icons.mark_email_unread_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isFailure ? 'Email ещё не подтверждён' : 'Проверьте почту',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (isFailure) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Письмо ещё не подтверждено. Откройте письмо и перейдите по ссылке.',
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Мы отправили ссылку для подтверждения на:\n$email',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Откройте письмо, перейдите по ссылке, затем вернитесь '
                          'в приложение и нажмите кнопку ниже.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () {
                          context.read<AuthCubit>().checkSession();
                        },
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Я подтвердил email'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          context.read<AuthCubit>().signOut();
                        },
                        child: const Text('Вернуться ко входу'),
                      ),
                    ],
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
