import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/households/presentation/pages/household_gate.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

import 'auth_page.dart';
import 'email_confirmation_page.dart';
import 'forgot_password_page.dart';
import 'password_reset_sent_page.dart';
import 'password_reset_success_page.dart';
import 'reset_password_page.dart';

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

          case AuthForgotPassword():
            return const ForgotPasswordPage();

          case AuthPasswordResetSent(:final email):
            return PasswordResetSentPage(email: email);

          case AuthPasswordResetReady(:final email):
            return ResetPasswordPage(email: email);

          case AuthPasswordResetSuccess():
            return const PasswordResetSuccessPage();

          case AuthEmailConfirmationRequired(:final email):
            return EmailConfirmationPage(email: email);

          case AuthAuthenticated(:final user):
            return HouseholdGate(currentMemberId: user.id);
        }
      },
    );
  }
}
