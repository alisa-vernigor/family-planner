import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/presentation/cubit/household_invitations_state.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';

void main() {
  final invitation = HouseholdInvitation(
    id: 'inv-1',
    householdId: 'household-1',
    householdName: 'Наша семья',
    invitedByDisplayName: 'Alice',
    createdAt: DateTime(2026, 7, 28),
    expiresAt: DateTime(2026, 8, 28),
  );

  group('HouseholdInvitationsState', () {
    group('1) All states create correctly', () {
      test('HouseholdInvitationsInitial создаётся без ошибок', () {
        const state = HouseholdInvitationsInitial();
        expect(state, isA<HouseholdInvitationsInitial>());
      });

      test('HouseholdInvitationsLoading создаётся без ошибок', () {
        const state = HouseholdInvitationsLoading();
        expect(state, isA<HouseholdInvitationsLoading>());
      });

      test('HouseholdInvitationsLoaded создаётся со списком приглашений', () {
        final state = HouseholdInvitationsLoaded(invitations: [invitation]);
        expect(state, isA<HouseholdInvitationsLoaded>());
        expect(state.invitations, [invitation]);
      });

      test(
        'HouseholdInvitationActionInProgress создаётся с приглашениями и id',
        () {
          final state = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          expect(state, isA<HouseholdInvitationActionInProgress>());
          expect(state.invitations, [invitation]);
          expect(state.invitationId, 'inv-1');
        },
      );

      test('HouseholdInvitationsFailure создаётся с сообщением', () {
        const state = HouseholdInvitationsFailure(message: 'Ошибка');
        expect(state, isA<HouseholdInvitationsFailure>());
        expect(state.message, 'Ошибка');
      });
    });

    group('2) HouseholdInvitationsLoaded stores list', () {
      test('пустой список', () {
        final state = HouseholdInvitationsLoaded(invitations: []);
        expect(state.invitations, isEmpty);
      });

      test('список с одним приглашением', () {
        final state = HouseholdInvitationsLoaded(invitations: [invitation]);
        expect(state.invitations.length, 1);
        expect(state.invitations.first.id, 'inv-1');
      });

      test('список с несколькими приглашениями', () {
        final inv2 = HouseholdInvitation(
          id: 'inv-2',
          householdId: 'household-2',
          householdName: 'Друзья',
          invitedByDisplayName: 'Bob',
          createdAt: DateTime(2026, 7, 28),
          expiresAt: DateTime(2026, 8, 28),
        );

        final state = HouseholdInvitationsLoaded(
          invitations: [invitation, inv2],
        );
        expect(state.invitations.length, 2);
        expect(state.invitations[0].id, 'inv-1');
        expect(state.invitations[1].id, 'inv-2');
      });

      test('список хранится напрямую (прозрачное хранение)', () {
        final list = [invitation];
        final state = HouseholdInvitationsLoaded(invitations: list);
        expect(
          identical(state.invitations, list),
          isTrue,
          reason: 'конструктор хранит ссылку на тот же список',
        );
      });
    });

    group('3) Different states are not equal', () {
      test('Initial != Loading', () {
        const initial = HouseholdInvitationsInitial();
        const loading = HouseholdInvitationsLoading();
        expect(initial == loading, isFalse);
      });

      test('Initial != Loaded', () {
        const initial = HouseholdInvitationsInitial();
        final loaded = HouseholdInvitationsLoaded(invitations: [invitation]);
        expect(initial == loaded, isFalse);
      });

      test('Loading != Loaded', () {
        const loading = HouseholdInvitationsLoading();
        final loaded = HouseholdInvitationsLoaded(invitations: [invitation]);
        expect(loading == loaded, isFalse);
      });

      test('Loaded != ActionInProgress', () {
        final loaded = HouseholdInvitationsLoaded(invitations: [invitation]);
        final inProgress = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );
        expect(loaded == inProgress, isFalse);
      });

      test('ActionInProgress != Failure', () {
        final inProgress = HouseholdInvitationActionInProgress(
          invitations: [invitation],
          invitationId: 'inv-1',
        );
        const failure = HouseholdInvitationsFailure(message: 'Ошибка');
        expect(inProgress == failure, isFalse);
      });

      test('Failure != Initial', () {
        const failure = HouseholdInvitationsFailure(message: 'Ошибка');
        const initial = HouseholdInvitationsInitial();
        expect(failure == initial, isFalse);
      });
    });

    group('4) Equatable props', () {
      group('HouseholdInvitationsInitial', () {
        test('два экземпляра равны', () {
          expect(
            const HouseholdInvitationsInitial(),
            const HouseholdInvitationsInitial(),
          );
        });

        test('props пустой', () {
          expect(const HouseholdInvitationsInitial().props, isEmpty);
        });
      });

      group('HouseholdInvitationsLoading', () {
        test('два экземпляра равны', () {
          expect(
            const HouseholdInvitationsLoading(),
            const HouseholdInvitationsLoading(),
          );
        });

        test('props пустой', () {
          expect(const HouseholdInvitationsLoading().props, isEmpty);
        });
      });

      group('HouseholdInvitationsLoaded', () {
        test('одинаковые списки — равны', () {
          final a = HouseholdInvitationsLoaded(invitations: [invitation]);
          final b = HouseholdInvitationsLoaded(invitations: [invitation]);
          expect(a, equals(b));
        });

        test('разные списки — не равны', () {
          final a = HouseholdInvitationsLoaded(invitations: [invitation]);
          final b = HouseholdInvitationsLoaded(invitations: []);
          expect(a == b, isFalse);
        });

        test('props содержит invitations', () {
          final state = HouseholdInvitationsLoaded(invitations: [invitation]);
          expect(state.props, [
            [invitation],
          ]);
        });
      });

      group('HouseholdInvitationActionInProgress', () {
        test('одинаковые поля — равны', () {
          final a = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          final b = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          expect(a, equals(b));
        });

        test('разный invitationId — не равны', () {
          final a = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          final b = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-2',
          );
          expect(a == b, isFalse);
        });

        test('разные invitations — не равны', () {
          final a = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          final b = HouseholdInvitationActionInProgress(
            invitations: [],
            invitationId: 'inv-1',
          );
          expect(a == b, isFalse);
        });

        test('props содержит invitations и invitationId', () {
          final state = HouseholdInvitationActionInProgress(
            invitations: [invitation],
            invitationId: 'inv-1',
          );
          expect(state.props, [
            [invitation],
            'inv-1',
          ]);
        });
      });

      group('HouseholdInvitationsFailure', () {
        test('одинаковые сообщения — равны', () {
          expect(
            const HouseholdInvitationsFailure(message: 'Ошибка'),
            const HouseholdInvitationsFailure(message: 'Ошибка'),
          );
        });

        test('разные сообщения — не равны', () {
          expect(
            const HouseholdInvitationsFailure(message: 'Ошибка') ==
                const HouseholdInvitationsFailure(message: 'Другая'),
            isFalse,
            reason: 'разные сообщения не должны быть равны',
          );
        });

        test('props содержит message', () {
          const state = HouseholdInvitationsFailure(message: 'Ошибка');
          expect(state.props, ['Ошибка']);
        });
      });
    });
  });
}
