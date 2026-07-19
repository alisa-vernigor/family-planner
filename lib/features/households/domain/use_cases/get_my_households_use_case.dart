import '../entities/household.dart';
import '../repositories/household_repository.dart';

final class GetMyHouseholdsUseCase {
  const GetMyHouseholdsUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<List<Household>> call() {
    return repository.getMyHouseholds();
  }
}
