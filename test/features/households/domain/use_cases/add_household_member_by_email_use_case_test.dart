import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/add_household_member_by_email_use_case.dart';

void main() {
  const member = HouseholdMember(
    profileId: 'profile-2',
    displayName: 'Иван',
    role: 'member',
  );

  group('AddHouseholdMemberByEmailUseCase', () {
    test('очищает email и приводит его к нижнему регистру', () async {
      final repository = FakeHouseholdRepository();
      final useCase = AddHouseholdMemberByEmailUseCase(repository: repository);

      final result = await useCase(
        householdId: 'household-1',
        email: '  IVAN@Example.COM  ',
      );

      expect(result, member);
      expect(repository.receivedHouseholdId, 'household-1');
      expect(repository.receivedEmail, 'ivan@example.com');
    });

    test('выбрасывает исключение для пустого email', () {
      final repository = FakeHouseholdRepository();
      final useCase = AddHouseholdMemberByEmailUseCase(repository: repository);

      expect(
        () => useCase(householdId: 'household-1', email: '   '),
        throwsA(isA<HouseholdMemberEmailInvalidException>()),
      );

      expect(repository.addMemberWasCalled, isFalse);
    });

    test('выбрасывает исключение для email без символа @', () {
      final repository = FakeHouseholdRepository();
      final useCase = AddHouseholdMemberByEmailUseCase(repository: repository);

      expect(
        () => useCase(householdId: 'household-1', email: 'ivan.example.com'),
        throwsA(isA<HouseholdMemberEmailInvalidException>()),
      );

      expect(repository.addMemberWasCalled, isFalse);
    });
  });
}

final class FakeHouseholdRepository implements HouseholdRepository {
  String? receivedHouseholdId;
  String? receivedEmail;
  bool addMemberWasCalled = false;

  @override
  Future<HouseholdMember> addMemberByEmail({
    required String householdId,
    required String email,
  }) async {
    addMemberWasCalled = true;
    receivedHouseholdId = householdId;
    receivedEmail = email;

    return const HouseholdMember(
      profileId: 'profile-2',
      displayName: 'Иван',
      role: 'member',
    );
  }

  @override
  Future<Household> create({required String name}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Household>> getMyHouseholds() {
    throw UnimplementedError();
  }

  @override
  Future<List<HouseholdMember>> getMembers({required String householdId}) {
    throw UnimplementedError();
  }
}
