import '../entities/household.dart';
import '../repositories/household_repository.dart';

final class CreateHouseholdUseCase {
  const CreateHouseholdUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<Household> call({required String name}) {
    return repository.create(name: name.trim());
  }
}
