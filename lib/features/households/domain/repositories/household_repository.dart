import '../entities/household.dart';
import '../entities/household_member.dart';

abstract interface class HouseholdRepository {
  Future<List<Household>> getMyHouseholds();

  Future<Household> create({required String name});

  Future<List<HouseholdMember>> getMembers({required String householdId});

  Future<HouseholdMember> addMemberByEmail({
    required String householdId,
    required String email,
  });
}
