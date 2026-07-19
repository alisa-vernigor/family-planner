import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final class SignUpUseCase {
  const SignUpUseCase({required this.repository});

  final AuthRepository repository;

  Future<AppUser?> call({
    required String email,
    required String password,
    required String displayName,
  }) {
    return repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }
}
