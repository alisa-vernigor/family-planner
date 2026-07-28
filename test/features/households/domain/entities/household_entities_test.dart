import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';

void main() {
  group('Household', () {
    test('constructor assigns fields', () {
      const household = Household(id: 'h-1', name: 'Наша семья');

      expect(household.id, 'h-1');
      expect(household.name, 'Наша семья');
    });

    test('equality — одинаковые объекты равны', () {
      const a = Household(id: 'h-1', name: 'Наша семья');
      const b = Household(id: 'h-1', name: 'Наша семья');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality — разные объекты не равны', () {
      const a = Household(id: 'h-1', name: 'Наша семья');
      const b = Household(id: 'h-2', name: 'Другая семья');

      expect(a, isNot(equals(b)));
    });

    test('props matches id and name', () {
      const household = Household(id: 'h-1', name: 'Наша семья');

      expect(household.props, [household.id, household.name]);
    });
  });

  group('HouseholdInvitation', () {
    test('constructor assigns fields', () {
      final now = DateTime(2026, 7, 25, 12);
      final expiresAt = now.add(const Duration(days: 7));

      final invitation = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: expiresAt,
      );

      expect(invitation.id, 'inv-1');
      expect(invitation.householdId, 'h-1');
      expect(invitation.householdName, 'Наша семья');
      expect(invitation.invitedByDisplayName, 'Алиса');
      expect(invitation.createdAt, now);
      expect(invitation.expiresAt, expiresAt);
    });

    test('equality — одинаковые объекты равны', () {
      final now = DateTime(2026, 7, 25);

      final a = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );
      final b = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality — разные объекты не равны', () {
      final now = DateTime(2026, 7, 25);

      final a = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );
      final b = HouseholdInvitation(
        id: 'inv-2',
        householdId: 'h-2',
        householdName: 'Другая семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );

      expect(a, isNot(equals(b)));
    });

    test('props matches all fields', () {
      final now = DateTime(2026, 7, 25);
      final expiresAt = now.add(const Duration(days: 7));

      final invitation = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: expiresAt,
      );

      expect(
        invitation.props,
        [
          invitation.id,
          invitation.householdId,
          invitation.householdName,
          invitation.invitedByDisplayName,
          invitation.createdAt,
          invitation.expiresAt,
        ],
      );
    });
  });

  group('HouseholdInvitationsState', () {
    group('HouseholdInvitationsInitial', () {
      test('создаётся без параметров', () {
        const state = HouseholdInvitationsInitial();

        expect(state.props, isEmpty);
      });

      test('equality', () {
        const a = HouseholdInvitationsInitial();
        const b = HouseholdInvitationsInitial();

        expect(a, equals(b));
      });
    });

    group('HouseholdInvitationsLoading', () {
      test('создаётся без параметров', () {
        const state = HouseholdInvitationsLoading();

        expect(state.props, isEmpty);
      });

      test('equality', () {
        const a = HouseholdInvitationsLoading();
        const b = HouseholdInvitationsLoading();

        expect(a, equals(b));
      });
    });

    group('HouseholdInvitationsLoaded', () {
      test('constructor assigns fields', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final state = HouseholdInvitationsLoaded(
          invitations: [invitation],
        );

        expect(state.invitations, [invitation]);
      });

      test('props contains invitations', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final state = HouseholdInvitationsLoaded(
          invitations: [invitation],
        );

        expect(state.props, [state.invitations]);
      });

      test('equality', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final a = HouseholdInvitationsLoaded(invitations: [invitation]);
        final b = HouseholdInvitationsLoaded(invitations: [invitation]);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('HouseholdInvitationActionInProgress', () {
      test('constructor assigns fields', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final state = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );

        expect(state.invitations, [invitation]);
        expect(state.invitationId, 'inv-1');
      });

      test('props contains invitations and invitationId', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final state = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );

        expect(state.props, [state.invitations, state.invitationId]);
      });

      test('equality', () {
        final now = DateTime(2026, 7, 25);
        final invitation = HouseholdInvitation(
          id: 'inv-1',
          householdId: 'h-1',
          householdName: 'Наша семья',
          invitedByDisplayName: 'Алиса',
          createdAt: now,
          expiresAt: now,
        );

        final a = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );
        final b = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('HouseholdInvitationsFailure', () {
      test('constructor assigns fields', () {
        const state = HouseholdInvitationsFailure(
          message: 'Ошибка загрузки',
        );

        expect(state.message, 'Ошибка загрузки');
      });

      test('props contains message', () {
        const state = HouseholdInvitationsFailure(
          message: 'Ошибка загрузки',
        );

        expect(state.props, ['Ошибка загрузки']);
      });

      test('equality', () {
        const a = HouseholdInvitationsFailure(message: 'Ошибка');
        const b = HouseholdInvitationsFailure(message: 'Ошибка');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('разные сообщения не равны', () {
        const a = HouseholdInvitationsFailure(message: 'Ошибка А');
        const b = HouseholdInvitationsFailure(message: 'Ошибка Б');

        expect(a, isNot(equals(b)));
      });
    });
  });
}
