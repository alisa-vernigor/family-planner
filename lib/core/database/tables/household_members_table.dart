import 'package:drift/drift.dart';

/// Local cache of household members (mirrors `household_members` +
/// `profiles` join).
class HouseholdMembers extends Table {
  TextColumn get profileId => text()();
  TextColumn get householdId => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role => text()();

  @override
  Set<Column> get primaryKey => {profileId, householdId};
}
