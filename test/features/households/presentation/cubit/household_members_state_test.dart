import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/presentation/cubit/household_members_state.dart';

void main() {
  const member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Alice',
    avatarUrl: 'https://example.com/avatar.png',
    role: 'owner',
  );

  const anotherMember = HouseholdMember(
    profileId: 'user-2',
    displayName: 'Bob',
    role: 'member',
  );

  group('HouseholdMembersState', () {
    test('HouseholdMembersInitial создаётся правильно', () {
      const state = HouseholdMembersInitial();

      expect(state, isA<HouseholdMembersInitial>());
      expect(state.props, isEmpty);
    });

    test('HouseholdMembersLoading создаётся правильно', () {
      const state = HouseholdMembersLoading();

      expect(state, isA<HouseholdMembersLoading>());
      expect(state.props, isEmpty);
    });

    test('HouseholdMembersLoaded создаётся правильно и хранит участников', () {
      const members = [member, anotherMember];
      const state = HouseholdMembersLoaded(members: members);

      expect(state, isA<HouseholdMembersLoaded>());
      expect(state.members, hasLength(2));
      expect(state.members[0].profileId, 'user-1');
      expect(state.members[0].displayName, 'Alice');
      expect(state.members[0].avatarUrl, 'https://example.com/avatar.png');
      expect(state.members[0].role, 'owner');
      expect(state.members[1].profileId, 'user-2');
      expect(state.members[1].displayName, 'Bob');
      expect(state.members[1].avatarUrl, isNull);
      expect(state.members[1].role, 'member');
    });

    test('HouseholdInvitationSending создаётся правильно и хранит участников', () {
      const members = [member];
      const state = HouseholdInvitationSending(members: members);

      expect(state, isA<HouseholdInvitationSending>());
      expect(state.members, hasLength(1));
      expect(state.members.single.profileId, 'user-1');
    });

    test('HouseholdInvitationSent создаётся правильно и хранит участников', () {
      const members = [anotherMember];
      const state = HouseholdInvitationSent(members: members);

      expect(state, isA<HouseholdInvitationSent>());
      expect(state.members, hasLength(1));
      expect(state.members.single.displayName, 'Bob');
    });

    test('HouseholdMembersFailure создаётся правильно и хранит сообщение', () {
      const state = HouseholdMembersFailure(message: 'Ошибка сети');

      expect(state, isA<HouseholdMembersFailure>());
      expect(state.message, 'Ошибка сети');
    });
  });

  group('Equatable equality', () {
    test('два HouseholdMembersInitial равны', () {
      expect(
        const HouseholdMembersInitial(),
        equals(const HouseholdMembersInitial()),
      );
    });

    test('два HouseholdMembersLoading равны', () {
      expect(
        const HouseholdMembersLoading(),
        equals(const HouseholdMembersLoading()),
      );
    });

    test('HouseholdMembersLoaded равен при одинаковых members', () {
      const members = [member, anotherMember];

      expect(
        const HouseholdMembersLoaded(members: members),
        equals(const HouseholdMembersLoaded(members: members)),
      );
    });

    test('HouseholdMembersLoaded НЕ равен при разных members', () {
      expect(
        const HouseholdMembersLoaded(members: [member]),
        isNot(equals(const HouseholdMembersLoaded(members: [anotherMember]))),
      );
    });

    test('HouseholdInvitationSending равен при одинаковых members', () {
      const members = [member];

      expect(
        const HouseholdInvitationSending(members: members),
        equals(const HouseholdInvitationSending(members: members)),
      );
    });

    test('HouseholdInvitationSending НЕ равен при разных members', () {
      expect(
        const HouseholdInvitationSending(members: [member]),
        isNot(
          equals(const HouseholdInvitationSending(members: [anotherMember])),
        ),
      );
    });

    test('HouseholdInvitationSent равен при одинаковых members', () {
      const members = [anotherMember];

      expect(
        const HouseholdInvitationSent(members: members),
        equals(const HouseholdInvitationSent(members: members)),
      );
    });

    test('HouseholdInvitationSent НЕ равен при разных members', () {
      expect(
        const HouseholdInvitationSent(members: [member]),
        isNot(
          equals(const HouseholdInvitationSent(members: [anotherMember])),
        ),
      );
    });

    test('HouseholdMembersFailure равен при одинаковом message', () {
      expect(
        const HouseholdMembersFailure(message: 'Ошибка'),
        equals(const HouseholdMembersFailure(message: 'Ошибка')),
      );
    });

    test('HouseholdMembersFailure НЕ равен при разном message', () => () {
      expect(
        const HouseholdMembersFailure(message: 'Ошибка А'),
        isNot(equals(const HouseholdMembersFailure(message: 'Ошибка Б'))),
      );
    });

    test('разные подтипы HouseholdMembersState НЕ равны', () {
      expect(
        const HouseholdMembersInitial(),
        isNot(equals(const HouseholdMembersLoading())),
      );

      expect(
        const HouseholdMembersInitial(),
        isNot(
          equals(const HouseholdMembersLoaded(members: [member])),
        ),
      );

      expect(
        const HouseholdMembersFailure(message: 'Ошибка'),
        isNot(equals(const HouseholdMembersInitial())),
      );
    });
  });
}
