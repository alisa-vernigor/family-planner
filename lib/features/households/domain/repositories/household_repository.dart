import '../entities/household.dart';
import '../entities/household_invitation.dart';
import '../entities/household_member.dart';

abstract interface class HouseholdRepository {
  Future<List<Household>> getMyHouseholds();

  Future<Household> create({required String name});

  Future<List<HouseholdMember>> getMembers({required String householdId});

  Future<void> createInvitation({
    required String householdId,
    required String email,
  });

  Future<List<HouseholdInvitation>> getPendingInvitations();

  Future<String> acceptInvitation({required String invitationId});

  Future<void> declineInvitation({required String invitationId});

  Future<void> leaveHousehold({required String householdId});

  Future<void> removeMember({
    required String householdId,
    required String profileId,
  });

  Future<void> deleteHousehold({required String householdId});

  Future<void> updateHousehold({
    required String householdId,
    required String name,
  });
}
