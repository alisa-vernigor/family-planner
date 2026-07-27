import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/auth/domain/use_cases/get_current_user_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_up_use_case.dart';

import 'auth_state.dart';

final class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.getCurrentUserUseCase,
    required this.signInUseCase,
    required this.signOutUseCase,
    required this.signUpUseCase,
    this.enableAuthListener = true,
  }) : super(const AuthInitial()) {
    if (enableAuthListener) _initAuthListener();
  }

  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SignInUseCase signInUseCase;
  final SignOutUseCase signOutUseCase;
  final SignUpUseCase signUpUseCase;
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
    final user = getCurrentUserUseCase();

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
      final user = await signUpUseCase(
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
      final user = await signInUseCase(email: email.trim(), password: password);

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
      await signOutUseCase();
      AppLogger.info('Пользователь вышел из аккаунта');
      emit(const AuthUnauthenticated());
    } catch (exception, stackTrace) {
      _emitUnexpectedFailure(exception, stackTrace);
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
