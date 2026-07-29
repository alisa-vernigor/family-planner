import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/entities/auth_event.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

void main() {
  const user = AppUser(id: 'user-1', email: 'anna@example.com');

  AuthCubit createCubit({
    AppUser? currentUser,
    AppUser? signInResult,
    AppUser? signUpResult,
    bool signOutThrows = false,
    bool signInThrowsGeneric = false,
    bool signUpThrowsAuthException = false,
    bool signUpThrowsGeneric = false,
  }) {
    final repository = FakeAuthRepository(
      currentUser: currentUser,
      signInResult: signInResult,
      signUpResult: signUpResult,
      signOutThrows: signOutThrows,
      signInThrowsGeneric: signInThrowsGeneric,
      signUpThrowsAuthException: signUpThrowsAuthException,
      signUpThrowsGeneric: signUpThrowsGeneric,
    );

    return AuthCubit(
      authRepository: repository,
      enableAuthListener: false,
    );
  }

  group('checkSession', () {
    blocTest<AuthCubit, AuthState>(
      'переходит в Unauthenticated, если сохранённой сессии нет',
      build: () => createCubit(),
      act: (cubit) => cubit.checkSession(),
      expect: () => const [AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'переходит в Authenticated, если сохранённая сессия есть',
      build: () => createCubit(currentUser: user),
      act: (cubit) => cubit.checkSession(),
      expect: () => const [AuthAuthenticated(user: user)],
    );
  });

  group('signIn', () {
    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Authenticated после успешного входа',
      build: () => createCubit(signInResult: user),
      act: (cubit) =>
          cubit.signIn(email: 'anna@example.com', password: 'password123'),
      expect: () => const [AuthLoading(), AuthAuthenticated(user: user)],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Failure при AuthException',
      build: () => createCubit(signInResult: null),
      act: (cubit) => cubit.signIn(
        email: 'anna@example.com',
        password: 'wrong',
      ),
      expect: () => const [
        AuthLoading(),
        AuthFailure(message: 'Неверный email или пароль.'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Failure при неожиданной ошибке',
      build: () => createCubit(signInThrowsGeneric: true),
      act: (cubit) => cubit.signIn(
        email: 'anna@example.com',
        password: 'password123',
      ),
      expect: () => const [
        AuthLoading(),
        AuthFailure(message: 'Произошла непредвиденная ошибка авторизации.'),
      ],
    );
  });

  group('signUp', () {
    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и подтверждение email, если регистрация без сессии',
      build: () => createCubit(signUpResult: null),
      act: (cubit) => cubit.signUp(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Аня',
      ),
      expect: () => const [
        AuthLoading(),
        AuthEmailConfirmationRequired(email: 'anna@example.com'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Authenticated после успешной регистрации',
      build: () => createCubit(signUpResult: user),
      act: (cubit) => cubit.signUp(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Аня',
      ),
      expect: () => const [
        AuthLoading(),
        AuthAuthenticated(user: user),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Failure с текстом ошибки при AuthException во время регистрации',
      build: () => createCubit(signUpThrowsAuthException: true),
      act: (cubit) => cubit.signUp(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Аня',
      ),
      expect: () => const [
        AuthLoading(),
        AuthFailure(message: 'Пользователь уже существует'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Failure при неожиданной ошибке во время регистрации',
      build: () => createCubit(signUpThrowsGeneric: true),
      act: (cubit) => cubit.signUp(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Аня',
      ),
      expect: () => const [
        AuthLoading(),
        AuthFailure(message: 'Произошла непредвиденная ошибка авторизации.'),
      ],
    );
  });

  group('signOut', () {
    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Unauthenticated после выхода',
      build: () => createCubit(),
      act: (cubit) => cubit.signOut(),
      expect: () => const [AuthLoading(), AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'выдаёт Loading и Unauthenticated при ошибке выхода',
      build: () => createCubit(signOutThrows: true),
      act: (cubit) => cubit.signOut(),
      expect: () => const [
        AuthLoading(),
        AuthUnauthenticated(),
      ],
    );
  });

  group('auth listener', () {
    test('не запускает слушатель Supabase при enableAuthListener: false', () async {
      final cubit = createCubit();
      expect(cubit.state, const AuthInitial());
      await cubit.close();
    });
  });
}

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.currentUser,
    this.signInResult,
    this.signUpResult,
    this.signOutThrows = false,
    this.signInThrowsGeneric = false,
    this.signUpThrowsAuthException = false,
    this.signUpThrowsGeneric = false,
  });

  @override
  final AppUser? currentUser;

  @override
  Stream<AuthStateEvent> get authStateEvents => _authController.stream;
  final _authController = StreamController<AuthStateEvent>.broadcast();

  final AppUser? signInResult;
  final AppUser? signUpResult;
  final bool signOutThrows;
  final bool signInThrowsGeneric;
  final bool signUpThrowsAuthException;
  final bool signUpThrowsGeneric;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInThrowsGeneric) {
      throw Exception('Ошибка сети');
    }
    if (signInResult == null) {
      throw AuthException('Неверный email или пароль.');
    }

    return signInResult!;
  }

  @override
  Future<void> signOut() async {
    if (signOutThrows) {
      throw Exception('Ошибка сети');
    }
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (signUpThrowsAuthException) {
      throw AuthException('Пользователь уже существует');
    }
    if (signUpThrowsGeneric) {
      throw Exception('Ошибка сети');
    }
    return signUpResult;
  }
}
