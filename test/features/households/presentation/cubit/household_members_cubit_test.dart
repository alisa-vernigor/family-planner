import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/add_household_member_by_email_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';

void main() {
  const owner = HouseholdMember(
    profileId: 'profile-1',
    displayName: 'Анна',
    role: 'owner',
  );

  const member = HouseholdMember(
    profileId: 'profile-2',
    displayName: 'Иван',
    role: 'member',
  );

  HouseholdMembersCubit createCubit({
    List<HouseholdMember> members = const [],
    HouseholdMember? memberToAdd,
    Object? loadException,
    Object? addException,
  }) {
    final repository = FakeHouseholdRepository(
      members: members,
      memberToAdd: memberToAdd,
      loadException: loadException,
      addException: addException,
    );

    return HouseholdMembersCubit(
      addHouseholdMemberByEmailUseCase: AddHouseholdMemberByEmailUseCase(
        repository: repository,
      ),
      getHouseholdMembersUseCase: GetHouseholdMembersUseCase(
        repository: repository,
      ),
    );
  }

  group('HouseholdMembersCubit', () {
    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'выдаёт Loading и Loaded после успешной загрузки участников',
      build: () => createCubit(members: const [owner, member]),
      act: (cubit) => cubit.load(householdId: 'household-1'),
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersLoaded(members: [owner, member]),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'выдаёт Loading и Failure при ошибке загрузки',
      build: () => createCubit(loadException: Exception('Нет подключения')),
      act: (cubit) => cubit.load(householdId: 'household-1'),
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersFailure(
          message: 'Не удалось загрузить участников семьи.',
        ),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'выдаёт Adding и Added при успешном добавлении участника',
      build: () => createCubit(memberToAdd: member),
      act: (cubit) => cubit.addByEmail(
        householdId: 'household-1',
        email: 'ivan@example.com',
      ),
      expect: () => const [
        HouseholdMemberAdding(members: []),
        HouseholdMemberAdded(members: [member], addedMember: member),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'сохраняет загруженных участников при добавлении нового',
      build: () => createCubit(members: const [owner], memberToAdd: member),
      seed: () => const HouseholdMembersLoaded(members: [owner]),
      act: (cubit) => cubit.addByEmail(
        householdId: 'household-1',
        email: 'ivan@example.com',
      ),
      expect: () => const [
        HouseholdMemberAdding(members: [owner]),
        HouseholdMemberAdded(members: [owner, member], addedMember: member),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'выдаёт Adding и Failure при ошибке добавления',
      build: () =>
          createCubit(addException: Exception('Пользователь не найден')),
      act: (cubit) => cubit.addByEmail(
        householdId: 'household-1',
        email: 'missing@example.com',
      ),
      expect: () => const [
        HouseholdMemberAdding(members: []),
        HouseholdMembersFailure(
          message: 'Не удалось добавить участника в семью.',
        ),
      ],
    );
  });
}

final class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    required this.members,
    this.memberToAdd,
    this.loadException,
    this.addException,
  });

  final List<HouseholdMember> members;
  final HouseholdMember? memberToAdd;
  final Object? loadException;
  final Object? addException;

  @override
  Future<HouseholdMember> addMemberByEmail({
    required String householdId,
    required String email,
  }) async {
    if (addException != null) {
      throw addException!;
    }

    if (memberToAdd == null) {
      throw StateError('Для теста не задан добавляемый участник.');
    }

    return memberToAdd!;
  }

  @override
  Future<List<HouseholdMember>> getMembers({
    required String householdId,
  }) async {
    if (loadException != null) {
      throw loadException!;
    }

    return members;
  }

  @override
  Future<Household> create({required String name}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Household>> getMyHouseholds() {
    throw UnimplementedError();
  }
}
