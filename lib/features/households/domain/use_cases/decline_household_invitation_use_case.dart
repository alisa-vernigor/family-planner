import '../repositories/household_repository.dart';

final class DeclineHouseholdInvitationUseCase {
  const DeclineHouseholdInvitationUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<void> call({required String invitationId}) {
    return repository.declineInvitation(invitationId: invitationId);
  }
}
