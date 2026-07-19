import '../entities/household_member.dart';
import '../repositories/household_repository.dart';

final class GetHouseholdMembersUseCase {
  const GetHouseholdMembersUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<List<HouseholdMember>> call({required String householdId}) {
    return repository.getMembers(householdId: householdId);
  }
}
