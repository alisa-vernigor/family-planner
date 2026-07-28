import '../../domain/repositories/profile_repository.dart';

final class GetProfileUseCase {
  GetProfileUseCase({required this.repository});

  final ProfileRepository repository;

  Future<dynamic> call(String profileId) {
    return repository.getProfile(profileId);
  }
}
