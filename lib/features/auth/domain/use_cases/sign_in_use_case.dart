import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final class SignInUseCase {
  const SignInUseCase({required this.repository});

  final AuthRepository repository;

  Future<AppUser> call({required String email, required String password}) {
    return repository.signIn(email: email, password: password);
  }
}
