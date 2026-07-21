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

void main() {
  const household = Household(id: 'household-1', name: 'Наша семья');

  HouseholdCubit createCubit({
    List<Household> households = const [],
    Household? createdHousehold,
    Object? loadException,
    Object? createException,
  }) {
    final repository = FakeHouseholdRepository(
      households: households,
      createdHousehold: createdHousehold,
      loadException: loadException,
      createException: createException,
    );

    return HouseholdCubit(
      createHouseholdUseCase: CreateHouseholdUseCase(repository: repository),
      getMyHouseholdsUseCase: GetMyHouseholdsUseCase(repository: repository),
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
        HouseholdFailure(message: 'Не удалось загрузить или создать семью.'),
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
  });

  final List<Household> households;
  final Household? createdHousehold;
  final Object? loadException;
  final Object? createException;

  @override
  Future<Household> create({required String name}) async {
    if (createException != null) {
      throw createException!;
    }

    if (createdHousehold == null) {
      throw StateError('Не задана семья для создания в тесте.');
    }

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
}
