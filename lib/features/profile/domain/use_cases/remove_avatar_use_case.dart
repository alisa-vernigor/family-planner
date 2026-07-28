import '../../domain/repositories/profile_repository.dart';

final class RemoveAvatarUseCase {
  RemoveAvatarUseCase({required this.repository});

  final ProfileRepository repository;

  Future<void> call(String profileId) {
    return repository.removeAvatar(profileId);
  }
}
