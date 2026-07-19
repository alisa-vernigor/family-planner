import 'package:flutter/material.dart';

final class SignOutButton extends StatelessWidget {
  const SignOutButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Выйти',
      onPressed: onPressed,
      icon: const Icon(Icons.logout),
    );
  }
}
