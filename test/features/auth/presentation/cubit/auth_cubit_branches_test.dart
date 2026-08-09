import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/entities/auth_event.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {
  final _authController = StreamController<AuthStateEvent>.broadcast();

  AppUser? _currentUser;

  void setCurrentUser(AppUser? user) => _currentUser = user;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AuthStateEvent> get authStateEvents => _authController.stream;

  void emitEvent(AuthStateEvent event) => _authController.add(event);

  void emitError(Object error) => _authController.addError(error);
}

void main() {
  const user = AppUser(id: 'user-1', email: 'anna@example.com');

  late _MockAuthRepository repo;

  AuthCubit buildCubit({bool enableAuthListener = true}) {
    repo = _MockAuthRepository();
    return AuthCubit(authRepository: repo, enableAuthListener: enableAuthListener);
  }

  tearDown(() {
    repo._authController.close();
  });

  group('AuthCubit — auth listener', () {
    test('signedOut → AuthUnauthenticated', () async {
      final cubit = buildCubit();
      await Future<void>.delayed(Duration.zero);

      repo.emitEvent(AuthStateEvent.signedOut);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const AuthUnauthenticated());
      await cubit.close();
    });

    test('tokenRefreshed → состояние не меняется', () async {
      final cubit = buildCubit();
      await Future<void>.delayed(Duration.zero);
      final before = cubit.state;

      repo.emitEvent(AuthStateEvent.tokenRefreshed);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, before);
      await cubit.close();
    });

    test('passwordRecovery → AuthPasswordResetReady с email', () async {
      final cubit = buildCubit();
      repo.setCurrentUser(user);
      await Future<void>.delayed(Duration.zero);

      repo.emitEvent(AuthStateEvent.passwordRecovery);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AuthPasswordResetReady>());
      expect((cubit.state as AuthPasswordResetReady).email, user.email);
      await cubit.close();
    });

    test('ошибка слушателя не роняет cubit', () async {
      final cubit = buildCubit();
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const AuthInitial());
      await cubit.close();
    });

    test('enableAuthListener=false не подписывается', () async {
      final cubit = buildCubit(enableAuthListener: false);
      await Future<void>.delayed(Duration.zero);

      repo.emitEvent(AuthStateEvent.signedOut);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const AuthInitial());
      await cubit.close();
    });
  });

  group('AuthCubit — sendPasswordReset / updatePassword', () {
    test('sendPasswordReset успешно → AuthPasswordResetSent', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.sendPasswordReset(email: any(named: 'email'), redirectTo: any(named: 'redirectTo')))
          .thenAnswer((_) async {});

      await cubit.sendPasswordReset(email: 'a@b.c');

      expect(cubit.state, isA<AuthPasswordResetSent>());
      expect((cubit.state as AuthPasswordResetSent).email, 'a@b.c');
      await cubit.close();
    });

    test('sendPasswordReset AuthException → AuthFailure', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.sendPasswordReset(email: any(named: 'email')))
          .thenThrow(const AuthException('Сеть недоступна'));

      await cubit.sendPasswordReset(email: 'a@b.c');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message, 'Сеть недоступна');
      await cubit.close();
    });

    test('sendPasswordReset generic error → сообщение по умолчанию', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.sendPasswordReset(email: any(named: 'email')))
          .thenThrow(Exception('boom'));

      await cubit.sendPasswordReset(email: 'a@b.c');

      expect(cubit.state, isA<AuthFailure>());
      await cubit.close();
    });

    test('updatePassword успешно → AuthPasswordResetSuccess', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.updatePassword(newPassword: any(named: 'newPassword')))
          .thenAnswer((_) async {});

      await cubit.updatePassword(newPassword: 'secret123');

      expect(cubit.state, const AuthPasswordResetSuccess());
      await cubit.close();
    });

    test('updatePassword AuthException → AuthFailure', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.updatePassword(newPassword: any(named: 'newPassword')))
          .thenThrow(const AuthException('Слабый пароль'));

      await cubit.updatePassword(newPassword: '123');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message, 'Слабый пароль');
      await cubit.close();
    });
  });

  group('AuthCubit — навигация и общие ветки', () {
    test('showForgotPassword → AuthForgotPassword', () async {
      final cubit = buildCubit(enableAuthListener: false);
      cubit.showForgotPassword();

      expect(cubit.state, const AuthForgotPassword());
      await cubit.close();
    });

    test('showSignIn → AuthUnauthenticated', () async {
      final cubit = buildCubit(enableAuthListener: false);
      cubit.showSignIn();

      expect(cubit.state, const AuthUnauthenticated());
      await cubit.close();
    });

    test('signIn с generic error → AuthFailure с сообщением по умолчанию', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('network'));

      await cubit.signIn(email: 'a@b.c', password: 'pass');

      final state = cubit.state;
      expect(state, isA<AuthFailure>());
      expect((state as AuthFailure).message, contains('непредвиденная'));
      await cubit.close();
    });

    test('signIn с AuthException c пустым сообщением → дефолт', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException(''));

      await cubit.signIn(email: 'a@b.c', password: 'pass');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message, contains('Не удалось'));
      await cubit.close();
    });

    test('signUp с AuthException → AuthFailure', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.signUp(email: any(named: 'email'), password: any(named: 'password'), displayName: any(named: 'displayName')))
          .thenThrow(const AuthException('Пользователь уже существует'));

      await cubit.signUp(email: 'a@b.c', password: 'pass', displayName: 'Anna');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message, 'Пользователь уже существует');
      await cubit.close();
    });

    test('signOut с ошибкой → AuthUnauthenticated', () async {
      final cubit = buildCubit(enableAuthListener: false);
      when(() => repo.signOut()).thenThrow(Exception('boom'));

      await cubit.signOut();

      expect(cubit.state, const AuthUnauthenticated());
      await cubit.close();
    });

    test('checkSession без пользователя → AuthUnauthenticated', () async {
      final cubit = buildCubit(enableAuthListener: false);
      cubit.checkSession();

      expect(cubit.state, const AuthUnauthenticated());
      await cubit.close();
    });

    test('checkSession с пользователем → AuthAuthenticated', () async {
      final cubit = buildCubit(enableAuthListener: false);
      repo.setCurrentUser(user);
      cubit.checkSession();

      expect(cubit.state, const AuthAuthenticated(user: user));
      await cubit.close();
    });
  });
}
