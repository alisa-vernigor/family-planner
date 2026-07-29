import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/household_members_table.dart';

part 'household_members_dao.g.dart';

/// DAO for reading/writing household members in the local SQLite database.
@DriftAccessor(tables: [HouseholdMembers])
class HouseholdMembersDao extends DatabaseAccessor<AppDatabase>
    with _$HouseholdMembersDaoMixin {
  HouseholdMembersDao(super.db);

  /// Get all cached members for a household.
  Future<List<HouseholdMember>> getMembers(String householdId) {
    return (select(householdMembers)
          ..where((m) => m.householdId.equals(householdId)))
        .get();
  }

  /// Insert or replace a household member.
  Future<void> upsertMember(HouseholdMembersCompanion member) {
    return into(householdMembers).insertOnConflictUpdate(member);
  }

  /// Batch upsert members.
  Future<void> upsertMembers(List<HouseholdMembersCompanion> members) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(householdMembers, members);
    });
  }

  /// Remove all members for a household.
  Future<void> clearHousehold(String householdId) {
    return (delete(householdMembers)
          ..where((m) => m.householdId.equals(householdId)))
        .go();
  }
}
