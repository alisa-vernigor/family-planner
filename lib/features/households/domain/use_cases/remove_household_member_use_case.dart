import '../repositories/household_repository.dart';

final class RemoveHouseholdMemberUseCase {
  const RemoveHouseholdMemberUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({
    required String householdId,
    required String profileId,
  }) {
    return repository.removeMember(
      householdId: householdId,
      profileId: profileId,
    );
  }
}
