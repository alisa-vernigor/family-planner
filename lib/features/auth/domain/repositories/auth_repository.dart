import '../entities/app_user.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();
}
