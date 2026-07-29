import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthEmailConfirmationRequired extends AuthState {
  const AuthEmailConfirmationRequired({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthFailure extends AuthState {
  const AuthFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

final class AuthForgotPassword extends AuthState {
  const AuthForgotPassword();
}

final class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthPasswordResetReady extends AuthState {
  const AuthPasswordResetReady({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthPasswordResetSuccess extends AuthState {
  const AuthPasswordResetSuccess();
}
