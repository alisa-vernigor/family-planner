import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';

final class PasswordResetSentPage extends StatelessWidget {
  const PasswordResetSentPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление пароля')),
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
                    Icons.mark_email_unread_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Проверьте почту',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Мы отправили ссылку для сброса пароля на:\n$email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Откройте письмо и перейдите по ссылке, '
                    'чтобы задать новый пароль.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () {
                      context.read<AuthCubit>().showSignIn();
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
  }
}
