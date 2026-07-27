import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_my_households_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/use_cases/delete_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/update_household_use_case.dart';

void main() {
  const household = Household(id: 'household-1', name: 'Наша семья');

  HouseholdCubit createCubit({
    List<Household> households = const [],
    Household? createdHousehold,
    Object? loadException,
    Object? createException,
    Object? deleteException,
    Object? updateException,
  }) {
    final repository = FakeHouseholdRepository(
      households: households,
      createdHousehold: createdHousehold,
      loadException: loadException,
      createException: createException,
      deleteException: deleteException,
      updateException: updateException,
    );

    return HouseholdCubit(
      createHouseholdUseCase: CreateHouseholdUseCase(repository: repository),
      getMyHouseholdsUseCase: GetMyHouseholdsUseCase(repository: repository),
      deleteHouseholdUseCase: DeleteHouseholdUseCase(repository: repository),
      updateHouseholdUseCase: UpdateHouseholdUseCase(repository: repository),
    );
  }

  group('HouseholdCubit', () {
    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Empty, когда у пользователя нет семей',
      build: createCubit,
      act: (cubit) => cubit.load(),
      expect: () => const [HouseholdLoading(), HouseholdEmpty()],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Loaded, когда семьи найдены',
      build: () => createCubit(households: const [household]),
      act: (cubit) => cubit.load(),
      expect: () => const [
        HouseholdLoading(),
        HouseholdLoaded(households: [household]),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Failure при ошибке загрузки',
      build: () => createCubit(loadException: Exception('Нет подключения')),
      act: (cubit) => cubit.load(),
      expect: () => const [
        HouseholdLoading(),
        HouseholdFailure(message: 'Не удалось загрузить или создать семью.'),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Loaded после создания семьи',
      build: () => createCubit(createdHousehold: household),
      act: (cubit) => cubit.create(name: 'Наша семья'),
      expect: () => const [
        HouseholdLoading(),
        HouseholdLoaded(households: [household]),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Failure при ошибке создания',
      build: () =>
          createCubit(createException: Exception('Ошибка базы данных')),
      act: (cubit) => cubit.create(name: 'Наша семья'),
      expect: () => const [
        HouseholdLoading(),
        HouseholdFailure(message: 'Не удалось создать семью.'),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loading и Loaded после удаления семьи (перезагружает список)',
      build: () => createCubit(households: const [household]),
      act: (cubit) => cubit.delete(householdId: 'household-1'),
      expect: () => const [
        HouseholdLoading(),
        HouseholdLoaded(households: [household]),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Failure при ошибке удаления (предыдущий стейт сохраняется)',
      build: () => createCubit(
        households: const [household],
        deleteException: Exception('Ошибка сети'),
      ),
      act: (cubit) => cubit.delete(householdId: 'household-1'),
      expect: () => const [
        HouseholdFailure(message: 'Не удалось удалить семью.'),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Loaded после переименования семьи',
      build: () => createCubit(households: const [household]),
      act: (cubit) =>
          cubit.update(householdId: 'household-1', name: 'Новое имя'),
      expect: () => const [
        HouseholdLoaded(households: [household]),
      ],
    );

    blocTest<HouseholdCubit, HouseholdState>(
      'выдаёт Failure при ошибке переименования',
      build: () => createCubit(
        households: const [household],
        updateException: Exception('Ошибка сети'),
      ),
      act: (cubit) =>
          cubit.update(householdId: 'household-1', name: 'Новое имя'),
      expect: () => const [
        HouseholdFailure(message: 'Не удалось переименовать семью.'),
      ],
    );
  });
}

final class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    required this.households,
    this.createdHousehold,
    this.loadException,
    this.createException,
    this.deleteException,
    this.updateException,
  });

  final List<Household> households;
  final Household? createdHousehold;
  final Object? loadException;
  final Object? createException;
  final Object? deleteException;
  final Object? updateException;

  bool _hasCreated = false;

  @override
  Future<Household> create({required String name}) async {
    if (createException != null) {
      throw createException!;
    }

    if (createdHousehold == null) {
      throw StateError('Не задана семья для создания в тесте.');
    }

    _hasCreated = true;

    return createdHousehold!;
  }

  @override
  Future<List<HouseholdMember>> getMembers({
    required String householdId,
  }) async {
    return const [];
  }

  @override
  Future<List<Household>> getMyHouseholds() async {
    if (loadException != null) {
      throw loadException!;
    }

    if (_hasCreated && createdHousehold != null) {
      return [createdHousehold!];
    }

    return households;
  }

  @override
  Future<void> createInvitation({
    required String householdId,
    required String email,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() {
    throw UnimplementedError();
  }

  @override
  Future<String> acceptInvitation({required String invitationId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> declineInvitation({required String invitationId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteHousehold({required String householdId}) async {
    if (deleteException != null) {
      throw deleteException!;
    }
  }

  @override
  Future<void> leaveHousehold({required String householdId}) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {}

  @override
  Future<void> updateHousehold({
    required String householdId,
    required String name,
  }) async {
    if (updateException != null) {
      throw updateException!;
    }
  }
}
