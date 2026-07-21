import '../repositories/household_repository.dart';

final class CreateHouseholdInvitationUseCase {
  const CreateHouseholdInvitationUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({required String householdId, required String email}) {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const HouseholdInvitationEmailInvalidException();
    }

    return repository.createInvitation(
      householdId: householdId,
      email: normalizedEmail,
    );
  }
}

final class HouseholdInvitationEmailInvalidException implements Exception {
  const HouseholdInvitationEmailInvalidException();

  @override
  String toString() {
    return 'HouseholdInvitationEmailInvalidException: '
        'укажите корректный email.';
  }
}
