import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';

import 'auth_state.dart';

final class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.authRepository,
    this.enableAuthListener = true,
  }) : super(const AuthInitial()) {
    if (enableAuthListener) _initAuthListener();
  }

  final AuthRepository authRepository;
  final bool enableAuthListener;

  StreamSubscription? _authSubscription;

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedOut) {
          emit(const AuthUnauthenticated());
        } else if (data.event == AuthChangeEvent.tokenRefreshed) {
          AppLogger.info('Токен обновлён');
        }
      },
      onError: (error) {
        AppLogger.error('Ошибка слушателя сессии', error: error);
      },
    );
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  void checkSession() {
    final user = authRepository.currentUser;

    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    AppLogger.info('Восстановлена сессия: userId=${user.id}');
    emit(AuthAuthenticated(user: user));
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    emit(const AuthLoading());

    try {
      final user = await authRepository.signUp(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );

      if (user == null) {
        emit(AuthEmailConfirmationRequired(email: email.trim()));
        return;
      }

      AppLogger.info('Пользователь зарегистрирован: userId=${user.id}');
      emit(AuthAuthenticated(user: user));
    } on AuthException catch (exception, stackTrace) {
      _emitAuthFailure(exception, stackTrace);
    } catch (exception, stackTrace) {
      _emitUnexpectedFailure(exception, stackTrace);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthLoading());

    try {
      final user = await authRepository.signIn(
        email: email.trim(),
        password: password,
      );

      AppLogger.info('Пользователь вошёл: userId=${user.id}');
      emit(AuthAuthenticated(user: user));
    } on AuthException catch (exception, stackTrace) {
      _emitAuthFailure(exception, stackTrace);
    } catch (exception, stackTrace) {
      _emitUnexpectedFailure(exception, stackTrace);
    }
  }

  Future<void> signOut() async {
    emit(const AuthLoading());

    try {
      await authRepository.signOut();
      AppLogger.info('Пользователь вышел из аккаунта');
      emit(const AuthUnauthenticated());
    } catch (exception, stackTrace) {
      AppLogger.error(
        'Не удалось выйти из аккаунта.',
        error: exception,
        stackTrace: stackTrace,
      );

      emit(const AuthUnauthenticated());
    }
  }

  void _emitAuthFailure(AuthException exception, StackTrace stackTrace) {
    final detail = exception.message;
    final message = detail != null && detail.isNotEmpty
        ? detail
        : 'Не удалось выполнить вход или регистрацию.';

    AppLogger.warning('Ошибка входа: $message');

    emit(AuthFailure(message: message));
  }

  void _emitUnexpectedFailure(Object exception, StackTrace stackTrace) {
    const message = 'Произошла непредвиденная ошибка авторизации.';

    AppLogger.error(message, error: exception, stackTrace: stackTrace);

    emit(const AuthFailure(message: message));
  }
}
