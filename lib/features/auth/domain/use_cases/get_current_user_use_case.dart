import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final class GetCurrentUserUseCase {
  const GetCurrentUserUseCase({required this.repository});

  final AuthRepository repository;

  AppUser? call() {
    return repository.currentUser;
  }
}
