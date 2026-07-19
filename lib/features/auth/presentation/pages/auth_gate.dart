import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/presentation/pages/household_gate.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

import 'auth_page.dart';
import 'email_confirmation_page.dart';

final class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

final class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    context.read<AuthCubit>().checkSession();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        switch (state) {
          case AuthInitial():
          case AuthLoading():
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case AuthUnauthenticated():
          case AuthFailure():
            return const AuthPage();

          case AuthEmailConfirmationRequired(:final email):
            return EmailConfirmationPage(email: email);

          case AuthAuthenticated(:final user):
            return HouseholdGate(currentMemberId: user.id);
        }
      },
    );
  }
}
