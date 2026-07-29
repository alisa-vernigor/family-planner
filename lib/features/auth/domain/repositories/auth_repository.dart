import 'dart:async';

import '../entities/app_user.dart';
import '../entities/auth_event.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Стрим событий аутентификации (signedOut, tokenRefreshed).
  Stream<AuthStateEvent> get authStateEvents;

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset({
    required String email,
    String? redirectTo,
  });

  Future<void> updatePassword({required String newPassword});
}
