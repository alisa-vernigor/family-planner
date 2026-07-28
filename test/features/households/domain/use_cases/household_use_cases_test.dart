import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/accept_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/decline_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_pending_household_invitations_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/leave_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/remove_household_member_use_case.dart';

final class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  late MockHouseholdRepository repository;

  setUp(() {
    repository = MockHouseholdRepository();
  });

  // ---------------------------------------------------------------------------
  // GetHouseholdMembersUseCase
  // ---------------------------------------------------------------------------

  group('GetHouseholdMembersUseCase', () {
    const householdId = 'household-1';

    final members = [
      const HouseholdMember(
        profileId: 'profile-1',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
        role: 'owner',
      ),
      const HouseholdMember(
        profileId: 'profile-2',
        displayName: 'Bob',
        role: 'member',
      ),
    ];

    test('returns members from repository', () async {
      when(() => repository.getMembers(householdId: householdId))
          .thenAnswer((_) async => members);

      final useCase = GetHouseholdMembersUseCase(repository: repository);
      final result = await useCase(householdId: householdId);

      expect(result, hasLength(2));
      expect(result[0].profileId, 'profile-1');
      expect(result[0].displayName, 'Alice');
      expect(result[0].avatarUrl, 'https://example.com/avatar.png');
      expect(result[0].role, 'owner');
      expect(result[1].profileId, 'profile-2');
      expect(result[1].displayName, 'Bob');
      expect(result[1].avatarUrl, isNull);
      expect(result[1].role, 'member');

      verify(() => repository.getMembers(householdId: householdId)).called(1);
    });

    test('handles members with null avatarUrl correctly', () async {
      final membersWithNullAvatar = [
        const HouseholdMember(
          profileId: 'profile-3',
          displayName: 'Charlie',
          role: 'member',
        ),
      ];

      when(() => repository.getMembers(householdId: householdId))
          .thenAnswer((_) async => membersWithNullAvatar);

      final useCase = GetHouseholdMembersUseCase(repository: repository);
      final result = await useCase(householdId: householdId);

      expect(result, hasLength(1));
      expect(result[0].avatarUrl, isNull);
      expect(result[0].profileId, 'profile-3');
      expect(result[0].displayName, 'Charlie');
      expect(result[0].role, 'member');

      verify(() => repository.getMembers(householdId: householdId)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // CreateHouseholdUseCase
  // ---------------------------------------------------------------------------

  group('CreateHouseholdUseCase', () {
    test('creates household with trimmed name', () async {
      const createdHousehold = Household(id: 'household-1', name: 'Our Home');

      when(() => repository.create(name: 'Our Home'))
          .thenAnswer((_) async => createdHousehold);

      final useCase = CreateHouseholdUseCase(repository: repository);
      final result = await useCase(name: '  Our Home  ');

      expect(result.id, 'household-1');
      expect(result.name, 'Our Home');

      verify(() => repository.create(name: 'Our Home')).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // CreateHouseholdInvitationUseCase
  // ---------------------------------------------------------------------------

  group('CreateHouseholdInvitationUseCase', () {
    const householdId = 'household-1';

    test('sends invitation with normalized email', () async {
      when(() => repository.createInvitation(
            householdId: householdId,
            email: 'user@example.com',
          )).thenAnswer((_) async {});

      final useCase = CreateHouseholdInvitationUseCase(repository: repository);
      await useCase(
        householdId: householdId,
        email: '  USER@EXAMPLE.COM  ',
      );

      verify(() => repository.createInvitation(
            householdId: householdId,
            email: 'user@example.com',
          )).called(1);
    });

    test('throws exception for empty email after trim', () async {
      final useCase = CreateHouseholdInvitationUseCase(repository: repository);

      expect(
        () => useCase(householdId: householdId, email: '   '),
        throwsA(isA<HouseholdInvitationEmailInvalidException>()),
      );
    });

    test('throws exception for email without @', () async {
      final useCase = CreateHouseholdInvitationUseCase(repository: repository);

      expect(
        () => useCase(householdId: householdId, email: 'invalid-email'),
        throwsA(isA<HouseholdInvitationEmailInvalidException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // AcceptHouseholdInvitationUseCase
  // ---------------------------------------------------------------------------

  group('AcceptHouseholdInvitationUseCase', () {
    const invitationId = 'invitation-1';
    const expectedHouseholdId = 'household-1';

    test('returns householdId on acceptance', () async {
      when(() => repository.acceptInvitation(invitationId: invitationId))
          .thenAnswer((_) async => expectedHouseholdId);

      final useCase = AcceptHouseholdInvitationUseCase(repository: repository);
      final result = await useCase(invitationId: invitationId);

      expect(result, expectedHouseholdId);

      verify(() => repository.acceptInvitation(invitationId: invitationId))
          .called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // DeclineHouseholdInvitationUseCase
  // ---------------------------------------------------------------------------

  group('DeclineHouseholdInvitationUseCase', () {
    const invitationId = 'invitation-1';

    test('declines invitation', () async {
      when(() => repository.declineInvitation(invitationId: invitationId))
          .thenAnswer((_) async {});

      final useCase = DeclineHouseholdInvitationUseCase(repository: repository);
      await useCase(invitationId: invitationId);

      verify(() => repository.declineInvitation(invitationId: invitationId))
          .called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // LeaveHouseholdUseCase
  // ---------------------------------------------------------------------------

  group('LeaveHouseholdUseCase', () {
    const householdId = 'household-1';

    test('leaves household', () async {
      when(() => repository.leaveHousehold(householdId: householdId))
          .thenAnswer((_) async {});

      final useCase = LeaveHouseholdUseCase(repository: repository);
      await useCase(householdId: householdId);

      verify(() => repository.leaveHousehold(householdId: householdId))
          .called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // RemoveHouseholdMemberUseCase
  // ---------------------------------------------------------------------------

  group('RemoveHouseholdMemberUseCase', () {
    const householdId = 'household-1';
    const profileId = 'profile-1';

    test('removes member from household', () async {
      when(() => repository.removeMember(
            householdId: householdId,
            profileId: profileId,
          )).thenAnswer((_) async {});

      final useCase = RemoveHouseholdMemberUseCase(repository: repository);
      await useCase(householdId: householdId, profileId: profileId);

      verify(() => repository.removeMember(
            householdId: householdId,
            profileId: profileId,
          )).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // GetPendingHouseholdInvitationsUseCase
  // ---------------------------------------------------------------------------

  group('GetPendingHouseholdInvitationsUseCase', () {
    final createdAt = DateTime.utc(2026, 7, 28);
    final expiresAt = DateTime.utc(2026, 8, 4);

    final invitations = [
      HouseholdInvitation(
        id: 'invitation-1',
        householdId: 'household-1',
        householdName: 'Our Home',
        invitedByDisplayName: 'Alice',
        createdAt: createdAt,
        expiresAt: expiresAt,
      ),
      HouseholdInvitation(
        id: 'invitation-2',
        householdId: 'household-2',
        householdName: 'Vacation Home',
        invitedByDisplayName: 'Bob',
        createdAt: createdAt,
        expiresAt: expiresAt,
      ),
    ];

    test('returns pending invitations', () async {
      when(() => repository.getPendingInvitations())
          .thenAnswer((_) async => invitations);

      final useCase =
          GetPendingHouseholdInvitationsUseCase(repository: repository);
      final result = await useCase();

      expect(result, hasLength(2));
      expect(result[0].id, 'invitation-1');
      expect(result[0].householdId, 'household-1');
      expect(result[0].householdName, 'Our Home');
      expect(result[0].invitedByDisplayName, 'Alice');
      expect(result[0].createdAt, createdAt);
      expect(result[0].expiresAt, expiresAt);
      expect(result[1].id, 'invitation-2');
      expect(result[1].householdId, 'household-2');
      expect(result[1].householdName, 'Vacation Home');
      expect(result[1].invitedByDisplayName, 'Bob');

      verify(() => repository.getPendingInvitations()).called(1);
    });
  });
}
