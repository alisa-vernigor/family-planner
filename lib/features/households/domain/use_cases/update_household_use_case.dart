import '../repositories/household_repository.dart';

final class UpdateHouseholdUseCase {
  const UpdateHouseholdUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({required String householdId, required String name}) {
    return repository.updateHousehold(householdId: householdId, name: name);
  }
}
