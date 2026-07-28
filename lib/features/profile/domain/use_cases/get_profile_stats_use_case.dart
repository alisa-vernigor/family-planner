import '../../domain/entities/profile_stats.dart';
import '../../domain/repositories/profile_repository.dart';

final class GetProfileStatsUseCase {
  GetProfileStatsUseCase({required this.repository});

  final ProfileRepository repository;

  Future<ProfileStats> call(String profileId) {
    return repository.getStats(profileId);
  }
}
