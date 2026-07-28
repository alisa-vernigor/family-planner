import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/leave_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/remove_household_member_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const member1 = HouseholdMember(
    profileId: 'member-1',
    displayName: 'Alice',
    avatarUrl: null,
    role: 'owner',
  );
  const member2 = HouseholdMember(
    profileId: 'member-2',
    displayName: 'Bob',
    avatarUrl: null,
    role: 'member',
  );
  const members = [member1, member2];
  const householdId = 'household-1';

  late MockHouseholdRepository repository;
  late HouseholdMembersCubit cubit;

  setUp(() {
    repository = MockHouseholdRepository();
    cubit = HouseholdMembersCubit(
      getHouseholdMembersUseCase:
          GetHouseholdMembersUseCase(repository: repository),
      createHouseholdInvitationUseCase:
          CreateHouseholdInvitationUseCase(repository: repository),
      leaveHouseholdUseCase:
          LeaveHouseholdUseCase(repository: repository),
      removeHouseholdMemberUseCase:
          RemoveHouseholdMemberUseCase(repository: repository),
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('HouseholdMembersCubit', () {
    test('initial state is HouseholdMembersInitial', () {
      expect(cubit.state, const HouseholdMembersInitial());
    });

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'load() emits [HouseholdMembersLoading, HouseholdMembersLoaded] on success',
      setUp: () {
        when(
          () => repository.getMembers(householdId: any(named: 'householdId')),
        ).thenAnswer((_) async => members);
      },
      build: () => cubit,
      act: (cubit) => cubit.load(householdId: householdId),
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersLoaded(members: members),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'load() emits [HouseholdMembersLoading, HouseholdMembersFailure] on error',
      setUp: () {
        when(
          () => repository.getMembers(householdId: any(named: 'householdId')),
        ).thenThrow(Exception('error'));
      },
      build: () => cubit,
      act: (cubit) => cubit.load(householdId: householdId),
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersFailure(message: 'Не удалось загрузить участников семьи.'),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'inviteByEmail() emits [HouseholdInvitationSending, HouseholdInvitationSent] on success',
      setUp: () {
        when(
          () => repository.getMembers(householdId: any(named: 'householdId')),
        ).thenAnswer((_) async => members);
        when(
          () => repository.createInvitation(
            householdId: any(named: 'householdId'),
            email: any(named: 'email'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => cubit,
      act: (cubit) async {
        await cubit.load(householdId: householdId);
        await cubit.inviteByEmail(
          householdId: householdId,
          email: 'test@example.com',
        );
      },
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersLoaded(members: members),
        HouseholdInvitationSending(members: members),
        HouseholdInvitationSent(members: members),
      ],
    );

    blocTest<HouseholdMembersCubit, HouseholdMembersState>(
      'inviteByEmail() emits failure on error',
      setUp: () {
        when(
          () => repository.getMembers(householdId: any(named: 'householdId')),
        ).thenAnswer((_) async => members);
        when(
          () => repository.createInvitation(
            householdId: any(named: 'householdId'),
            email: any(named: 'email'),
          ),
        ).thenThrow(Exception('error'));
      },
      build: () => cubit,
      act: (cubit) async {
        await cubit.load(householdId: householdId);
        await cubit.inviteByEmail(
          householdId: householdId,
          email: 'test@example.com',
        );
      },
      expect: () => const [
        HouseholdMembersLoading(),
        HouseholdMembersLoaded(members: members),
        HouseholdInvitationSending(members: members),
        HouseholdMembersFailure(message: 'Не удалось отправить приглашение.'),
      ],
    );

    test('leaveHousehold() calls repository.leaveHousehold and returns true', () async {
      when(
        () => repository.leaveHousehold(
          householdId: any(named: 'householdId'),
        ),
      ).thenAnswer((_) async {});

      final result = await cubit.leaveHousehold(householdId: householdId);

      expect(result, true);
      verify(
        () => repository.leaveHousehold(householdId: householdId),
      ).called(1);
    });

    test('leaveHousehold() returns false on exception', () async {
      when(
        () => repository.leaveHousehold(
          householdId: any(named: 'householdId'),
        ),
      ).thenThrow(Exception('error'));

      final result = await cubit.leaveHousehold(householdId: householdId);

      expect(result, false);
      expect(
        cubit.state,
        const HouseholdMembersFailure(message: 'Не удалось выйти из семьи.'),
      );
    });

    test('removeMember() calls repository.removeMember and returns true', () async {
      when(
        () => repository.getMembers(householdId: any(named: 'householdId')),
      ).thenAnswer((_) async => members);
      when(
        () => repository.removeMember(
          householdId: any(named: 'householdId'),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) async {});

      await cubit.load(householdId: householdId);

      final result = await cubit.removeMember(
        householdId: householdId,
        profileId: 'member-1',
      );

      expect(result, true);
      verify(
        () => repository.removeMember(
          householdId: householdId,
          profileId: 'member-1',
        ),
      ).called(1);
    });

    test('removeMember() returns false on exception', () async {
      when(
        () => repository.getMembers(householdId: any(named: 'householdId')),
      ).thenAnswer((_) async => members);
      when(
        () => repository.removeMember(
          householdId: any(named: 'householdId'),
          profileId: any(named: 'profileId'),
        ),
      ).thenThrow(Exception('error'));

      await cubit.load(householdId: householdId);

      final result = await cubit.removeMember(
        householdId: householdId,
        profileId: 'member-1',
      );

      expect(result, false);
      expect(
        cubit.state,
        const HouseholdMembersFailure(message: 'Не удалось удалить участника.'),
      );
    });
  });
}
