import '../repositories/auth_repository.dart';

final class SignOutUseCase {
  const SignOutUseCase({required this.repository});

  final AuthRepository repository;

  Future<void> call() {
    return repository.signOut();
  }
}
