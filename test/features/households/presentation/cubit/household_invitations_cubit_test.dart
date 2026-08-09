import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';
import '../../../../helpers/mock_repository_factory.dart';

void main() {
  final invitation = HouseholdInvitation(
    id: 'invitation-1',
    householdId: 'household-1',
    householdName: 'Our Home',
    invitedByDisplayName: 'Alice',
    createdAt: DateTime(2026, 7, 28),
    expiresAt: DateTime(2026, 8, 4),
  );

  const householdId = 'household-1';

  late MockRepositoryFactory mocks;

  HouseholdInvitationsCubit createCubit() {
    return HouseholdInvitationsCubit(
      householdRepository: mocks.household,
    );
  }

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  group('HouseholdInvitationsCubit', () {
    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '1) initial state is HouseholdInvitationsInitial',
      build: createCubit,
      verify: (cubit) {
        expect(cubit.state, const HouseholdInvitationsInitial());
      },
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '2) load() emits [HouseholdInvitationsLoading, HouseholdInvitationsLoaded]',
      setUp: () {
        when(() => mocks.household.getPendingInvitations())
            .thenAnswer((_) async => [invitation]);
      },
      build: createCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const HouseholdInvitationsLoading(),
        HouseholdInvitationsLoaded(invitations: [invitation]),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '3) load() emits HouseholdInvitationsFailure on error',
      setUp: () {
        when(() => mocks.household.getPendingInvitations())
            .thenThrow(Exception('Network error'));
      },
      build: createCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const HouseholdInvitationsLoading(),
        const HouseholdInvitationsFailure(
          message: 'Не удалось загрузить приглашения.',
        ),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '4) accept() emits [ActionInProgress, Loaded] and returns household ID',
      setUp: () {
        when(
          () => mocks.household.acceptInvitation(invitationId: any(named: 'invitationId')),
        ).thenAnswer((_) async => householdId);
      },
      seed: () => HouseholdInvitationsLoaded(invitations: [invitation]),
      build: createCubit,
      act: (cubit) async {
        final result = await cubit.accept(invitation: invitation);
        expect(result, householdId);
      },
      expect: () => [
        HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: invitation.id,
        ),
        HouseholdInvitationsLoaded(invitations: []),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '5) accept() emits HouseholdInvitationsFailure on error',
      setUp: () {
        when(
          () => mocks.household.acceptInvitation(invitationId: any(named: 'invitationId')),
        ).thenThrow(Exception('DB error'));
      },
      seed: () => HouseholdInvitationsLoaded(invitations: [invitation]),
      build: createCubit,
      act: (cubit) async {
        final result = await cubit.accept(invitation: invitation);
        expect(result, isNull);
      },
      expect: () => [
        HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: invitation.id,
        ),
        const HouseholdInvitationsFailure(
          message: 'Не удалось принять приглашение.',
        ),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '6) decline() emits [ActionInProgress, Loaded] on success',
      setUp: () {
        when(
          () => mocks.household.declineInvitation(invitationId: any(named: 'invitationId')),
        ).thenAnswer((_) async {});
      },
      seed: () => HouseholdInvitationsLoaded(invitations: [invitation]),
      build: createCubit,
      act: (cubit) => cubit.decline(invitation: invitation),
      expect: () => [
        HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: invitation.id,
        ),
        HouseholdInvitationsLoaded(invitations: []),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '7) decline() emits HouseholdInvitationsFailure on error',
      setUp: () {
        when(
          () => mocks.household.declineInvitation(invitationId: any(named: 'invitationId')),
        ).thenThrow(Exception('DB error'));
      },
      seed: () => HouseholdInvitationsLoaded(invitations: [invitation]),
      build: createCubit,
      act: (cubit) => cubit.decline(invitation: invitation),
      expect: () => [
        HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: invitation.id,
        ),
        const HouseholdInvitationsFailure(
          message: 'Не удалось отклонить приглашение.',
        ),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '8) accept() из initial состояния работает с пустым списком',
      setUp: () {
        when(
          () => mocks.household.acceptInvitation(invitationId: any(named: 'invitationId')),
        ).thenAnswer((_) async => householdId);
      },
      build: createCubit,
      act: (cubit) async {
        final result = await cubit.accept(invitation: invitation);
        expect(result, householdId);
      },
      expect: () => [
        const HouseholdInvitationActionInProgress(
          invitations: [],
          invitationId: 'invitation-1',
        ),
        const HouseholdInvitationsLoaded(invitations: []),
      ],
    );

    blocTest<HouseholdInvitationsCubit, HouseholdInvitationsState>(
      '9) accept() из ActionInProgress берёт текущий список приглашений',
      setUp: () {
        when(
          () => mocks.household.acceptInvitation(invitationId: any(named: 'invitationId')),
        ).thenAnswer((_) async => householdId);
      },
      seed: () => const HouseholdInvitationActionInProgress(
        invitations: [],
        invitationId: 'invitation-1',
      ),
      build: createCubit,
      act: (cubit) async {
        final result = await cubit.accept(invitation: invitation);
        expect(result, householdId);
      },
      // Первое ActionInProgress равно seed — bloc_test схлопывает дубликат.
      expect: () => const [
        HouseholdInvitationsLoaded(invitations: []),
      ],
    );
  });
}
