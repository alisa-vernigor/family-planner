import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/profile/presentation/cubit/profile_state.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';

void main() {
  group('ProfileState', () {
    final defaultProfile = UserProfile(
      id: 'user-1',
      displayName: 'Alice',
      avatarUrl: 'https://example.com/avatar.png',
      timezone: 'America/New_York',
      bio: 'Hello!',
    );

    group('ProfileInitial', () {
      test('props are empty', () {
        const state = ProfileInitial();
        expect(state.props, []);
      });
    });

    group('ProfileLoading', () {
      test('props are empty', () {
        const state = ProfileLoading();
        expect(state.props, []);
      });
    });

    group('ProfileLoaded', () {
      test('stores profile', () {
        final state = ProfileLoaded(profile: defaultProfile);
        expect(state.profile, defaultProfile);
      });

      test('props contains profile', () {
        final state = ProfileLoaded(profile: defaultProfile);
        expect(state.props, [defaultProfile]);
      });
    });

    group('ProfileUpdateSuccess', () {
      test('stores profile', () {
        final state = ProfileUpdateSuccess(profile: defaultProfile);
        expect(state.profile, defaultProfile);
      });

      test('props contains profile', () {
        final state = ProfileUpdateSuccess(profile: defaultProfile);
        expect(state.props, [defaultProfile]);
      });
    });

    group('AvatarUploading', () {
      test('stores profile', () {
        final state = AvatarUploading(profile: defaultProfile);
        expect(state.profile, defaultProfile);
      });

      test('props contains profile', () {
        final state = AvatarUploading(profile: defaultProfile);
        expect(state.props, [defaultProfile]);
      });
    });

    group('ProfileFailure', () {
      test('stores message', () {
        const state = ProfileFailure(message: 'Something went wrong');
        expect(state.message, 'Something went wrong');
      });

      test('props contains message', () {
        const state = ProfileFailure(message: 'Something went wrong');
        expect(state.props, ['Something went wrong']);
      });
    });

    group('equality', () {
      test('different states are not equal', () {
        const initial = ProfileInitial();
        const loading = ProfileLoading();
        expect(initial == loading, false);
        expect(initial != loading, true);
      });

      test('ProfileLoaded states with same profile are equal', () {
        final a = ProfileLoaded(profile: defaultProfile);
        final b = ProfileLoaded(profile: defaultProfile);
        expect(a == b, true);
        expect(a.props, b.props);
      });

      test('ProfileUpdateSuccess states with same profile are equal', () {
        final a = ProfileUpdateSuccess(profile: defaultProfile);
        final b = ProfileUpdateSuccess(profile: defaultProfile);
        expect(a == b, true);
      });

      test('AvatarUploading states with same profile are equal', () {
        final a = AvatarUploading(profile: defaultProfile);
        final b = AvatarUploading(profile: defaultProfile);
        expect(a == b, true);
      });

      test('ProfileFailure states with same message are equal', () {
        const a = ProfileFailure(message: 'error');
        const b = ProfileFailure(message: 'error');
        expect(a == b, true);
      });

      test('ProfileLoaded states with different profiles are not equal', () {
        final otherProfile = defaultProfile.copyWith(displayName: 'Bob');
        final a = ProfileLoaded(profile: defaultProfile);
        final b = ProfileLoaded(profile: otherProfile);
        expect(a == b, false);
      });

      test('ProfileUpdateSuccess states with different profiles are not equal',
          () {
        final otherProfile = defaultProfile.copyWith(displayName: 'Bob');
        final a = ProfileUpdateSuccess(profile: defaultProfile);
        final b = ProfileUpdateSuccess(profile: otherProfile);
        expect(a == b, false);
      });

      test('AvatarUploading states with different profiles are not equal', () {
        final otherProfile = defaultProfile.copyWith(displayName: 'Bob');
        final a = AvatarUploading(profile: defaultProfile);
        final b = AvatarUploading(profile: otherProfile);
        expect(a == b, false);
      });

      test('ProfileFailure states with different messages are not equal', () {
        const a = ProfileFailure(message: 'error');
        const b = ProfileFailure(message: 'different error');
        expect(a == b, false);
      });

      test('ProfileLoaded is not equal to ProfileFailure', () {
        final loaded = ProfileLoaded(profile: defaultProfile);
        const failure = ProfileFailure(message: 'error');
        expect(loaded == failure, false);
      });
    });
  });
}
