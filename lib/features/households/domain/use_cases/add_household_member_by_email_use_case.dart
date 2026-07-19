import '../entities/household_member.dart';
import '../repositories/household_repository.dart';

final class AddHouseholdMemberByEmailUseCase {
  const AddHouseholdMemberByEmailUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<HouseholdMember> call({
    required String householdId,
    required String email,
  }) {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const HouseholdMemberEmailInvalidException();
    }

    return repository.addMemberByEmail(
      householdId: householdId,
      email: normalizedEmail,
    );
  }
}

final class HouseholdMemberEmailInvalidException implements Exception {
  const HouseholdMemberEmailInvalidException();

  @override
  String toString() {
    return 'HouseholdMemberEmailInvalidException: некорректный email.';
  }
}
