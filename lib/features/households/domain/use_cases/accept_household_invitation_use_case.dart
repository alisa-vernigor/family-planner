import '../repositories/household_repository.dart';

final class AcceptHouseholdInvitationUseCase {
  const AcceptHouseholdInvitationUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<String> call({required String invitationId}) {
    return repository.acceptInvitation(invitationId: invitationId);
  }
}
