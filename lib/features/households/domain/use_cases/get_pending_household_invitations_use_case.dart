import '../entities/household_invitation.dart';
import '../repositories/household_repository.dart';

final class GetPendingHouseholdInvitationsUseCase {
  const GetPendingHouseholdInvitationsUseCase({required this.repository});

  final HouseholdRepository repository;

  Future<List<HouseholdInvitation>> call() {
    return repository.getPendingInvitations();
  }
}
