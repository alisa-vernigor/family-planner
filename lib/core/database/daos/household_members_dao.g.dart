// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_members_dao.dart';

// ignore_for_file: type=lint
mixin _$HouseholdMembersDaoMixin on DatabaseAccessor<AppDatabase> {
  $HouseholdMembersTable get householdMembers =>
      attachedDatabase.householdMembers;
  HouseholdMembersDaoManager get managers => HouseholdMembersDaoManager(this);
}

class HouseholdMembersDaoManager {
  final _$HouseholdMembersDaoMixin _db;
  HouseholdMembersDaoManager(this._db);
  $$HouseholdMembersTableTableManager get householdMembers =>
      $$HouseholdMembersTableTableManager(
        _db.attachedDatabase,
        _db.householdMembers,
      );
}
