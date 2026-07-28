import '../../domain/repositories/profile_repository.dart';

final class UpdateProfileUseCase {
  UpdateProfileUseCase({required this.repository});

  final ProfileRepository repository;

  Future<void> call({
    required String profileId,
    String? displayName,
    String? bio,
    String? timezone,
  }) {
    return repository.updateProfile(
      profileId: profileId,
      displayName: displayName,
      bio: bio,
      timezone: timezone,
    );
  }
}
