import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_state.dart';

const _user = AppUser(id: 'user-1', email: 'user@example.com');
const _otherUser = AppUser(id: 'user-2', email: 'other@example.com');

void main() {
  group('AuthInitial', () {
    test('props is empty', () {
      expect(const AuthInitial().props, []);
    });

    test('same props => equal', () {
      expect(const AuthInitial(), const AuthInitial());
    });
  });

  group('AuthLoading', () {
    test('props is empty', () {
      expect(const AuthLoading().props, []);
    });

    test('same props => equal', () {
      expect(const AuthLoading(), const AuthLoading());
    });
  });

  group('AuthUnauthenticated', () {
    test('props is empty', () {
      expect(const AuthUnauthenticated().props, []);
    });

    test('same props => equal', () {
      expect(const AuthUnauthenticated(), const AuthUnauthenticated());
    });
  });

  group('AuthAuthenticated', () {
    test('props stores user', () {
      const state = AuthAuthenticated(user: _user);
      expect(state.user, _user);
    });

    test('same props => equal', () {
      const state1 = AuthAuthenticated(user: _user);
      const state2 = AuthAuthenticated(user: _user);
      expect(state1, state2);
    });

    test('different user => not equal', () {
      const state1 = AuthAuthenticated(user: _user);
      const state2 = AuthAuthenticated(user: _otherUser);
      expect(state1, isNot(state2));
    });
  });

  group('AuthEmailConfirmationRequired', () {
    test('props stores email', () {
      const state = AuthEmailConfirmationRequired(email: 'test@example.com');
      expect(state.email, 'test@example.com');
    });

    test('same props => equal', () {
      const state1 = AuthEmailConfirmationRequired(email: 'test@example.com');
      const state2 = AuthEmailConfirmationRequired(email: 'test@example.com');
      expect(state1, state2);
    });

    test('different email => not equal', () {
      const state1 = AuthEmailConfirmationRequired(email: 'a@example.com');
      const state2 = AuthEmailConfirmationRequired(email: 'b@example.com');
      expect(state1, isNot(state2));
    });
  });

  group('AuthFailure', () {
    test('props stores message', () {
      const state = AuthFailure(message: 'error occurred');
      expect(state.message, 'error occurred');
    });

    test('same props => equal', () {
      const state1 = AuthFailure(message: 'error');
      const state2 = AuthFailure(message: 'error');
      expect(state1, state2);
    });

    test('different message => not equal', () {
      const state1 = AuthFailure(message: 'error a');
      const state2 = AuthFailure(message: 'error b');
      expect(state1, isNot(state2));
    });
  });

  group('Equatable across all states', () {
    test('different state types are not equal', () {
      expect(const AuthInitial(), isNot(const AuthLoading()));
      expect(const AuthInitial(), isNot(const AuthUnauthenticated()));
      expect(const AuthInitial(), isNot(AuthAuthenticated(user: _user)));
      expect(const AuthInitial(),
          isNot(AuthEmailConfirmationRequired(email: 'x@y.com')));
      expect(const AuthInitial(), isNot(AuthFailure(message: 'x')));

      expect(const AuthLoading(), isNot(const AuthUnauthenticated()));
      expect(const AuthLoading(), isNot(AuthAuthenticated(user: _user)));
    });
  });
}
