import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required this._client});

  final SupabaseClient _client;

  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;

    if (user == null || user.email == null) {
      return null;
    }

    return _toAppUser(user);
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final user = response.user;

    if (response.session == null || user == null || user.email == null) {
      return null;
    }

    return _toAppUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user == null || user.email == null) {
      throw const AuthUserNotReturnedException();
    }

    return _toAppUser(user);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  AppUser _toAppUser(User user) {
    return AppUser(id: user.id, email: user.email!);
  }
}

final class AuthUserNotReturnedException implements Exception {
  const AuthUserNotReturnedException();

  @override
  String toString() {
    return 'AuthUserNotReturnedException: '
        'Supabase не вернул пользователя после входа.';
  }
}
