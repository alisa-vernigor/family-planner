import '../repositories/household_repository.dart';

final class DeleteHouseholdUseCase {
  const DeleteHouseholdUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({required String householdId}) {
    return repository.deleteHousehold(householdId: householdId);
  }
}
