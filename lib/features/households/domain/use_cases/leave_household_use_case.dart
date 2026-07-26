import '../repositories/household_repository.dart';

final class LeaveHouseholdUseCase {
  const LeaveHouseholdUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({required String householdId}) {
    return repository.leaveHousehold(householdId: householdId);
  }
}
