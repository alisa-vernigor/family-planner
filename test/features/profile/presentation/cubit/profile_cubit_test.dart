import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore_for_file: prefer_const_constructors

import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_state.dart';
import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  const profileId = 'profile-1';
  final profile = UserProfile(
    id: profileId,
    displayName: 'Alice',
    avatarUrl: 'https://example.com/avatar.png',
    timezone: 'Europe/Moscow',
    bio: 'Hello!',
  );
  final bytes = Uint8List(0);
  const contentType = 'image/png';

  setUp(() {
    mocks = MockRepositoryFactory();
    registerFallbackValue(Uint8List(0));
  });

  ProfileCubit createCubit() {
    return ProfileCubit(
      profileRepository: mocks.profile,
    );
  }

  group('ProfileCubit', () {
    test('initial state is ProfileInitial', () {
      final cubit = createCubit();
      expect(cubit.state, const ProfileInitial());
    });

    group('load()', () {
      blocTest<ProfileCubit, ProfileState>(
        'emits [ProfileLoading, ProfileLoaded] with user',
        build: () {
          when(() => mocks.profile.getProfile(profileId))
              .thenAnswer((_) async => profile);
          return createCubit();
        },
        act: (cubit) => cubit.load(profileId),
        expect: () => [
          const ProfileLoading(),
          ProfileLoaded(profile: profile),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits [ProfileLoading, ProfileFailure] on throw',
        build: () {
          when(() => mocks.profile.getProfile(profileId))
              .thenThrow(Exception('error'));
          return createCubit();
        },
        act: (cubit) => cubit.load(profileId),
        expect: () => [
          const ProfileLoading(),
          const ProfileFailure(message: 'Не удалось загрузить профиль.'),
        ],
      );
    });

    group('updateProfile()', () {
      blocTest<ProfileCubit, ProfileState>(
        'emits [ProfileUpdateSuccess, ProfileLoaded] on success',
        build: () {
          when(
            () => mocks.profile.updateProfile(
              profileId: profileId,
              displayName: any(named: 'displayName'),
              bio: any(named: 'bio'),
              timezone: any(named: 'timezone'),
            ),
          ).thenAnswer((_) async {});
          when(() => mocks.profile.getProfile(profileId))
              .thenAnswer((_) async => profile);
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.updateProfile(profileId: profileId),
        expect: () => [
          ProfileUpdateSuccess(profile: profile),
          ProfileLoaded(profile: profile),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits ProfileFailure on update throw',
        build: () {
          when(
            () => mocks.profile.updateProfile(
              profileId: profileId,
              displayName: any(named: 'displayName'),
              bio: any(named: 'bio'),
              timezone: any(named: 'timezone'),
            ),
          ).thenThrow(Exception('error'));
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.updateProfile(profileId: profileId),
        expect: () => [
          ProfileUpdateSuccess(profile: profile),
          const ProfileFailure(message: 'Не удалось обновить профиль.'),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'does optimistic update from ProfileLoaded',
        build: () {
          when(
            () => mocks.profile.updateProfile(
              profileId: profileId,
              displayName: 'Bob',
              bio: any(named: 'bio'),
              timezone: any(named: 'timezone'),
            ),
          ).thenAnswer((_) async {});
          when(() => mocks.profile.getProfile(profileId))
              .thenThrow(Exception('error'));
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.updateProfile(
          profileId: profileId,
          displayName: 'Bob',
        ),
        expect: () => [
          ProfileUpdateSuccess(
            profile: profile.copyWith(displayName: 'Bob'),
          ),
          const ProfileFailure(message: 'Не удалось обновить профиль.'),
        ],
      );
    });

    group('uploadAvatar()', () {
      blocTest<ProfileCubit, ProfileState>(
        'emits [AvatarUploading, ProfileUpdateSuccess] on success',
        build: () {
          when(
            () => mocks.profile.uploadAvatar(
              profileId: profileId,
              bytes: any(named: 'bytes'),
              contentType: any(named: 'contentType'),
            ),
          ).thenAnswer((_) async => 'https://example.com/new-avatar.png');
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.uploadAvatar(
          profileId: profileId,
          bytes: bytes,
          contentType: contentType,
        ),
        expect: () => [
          AvatarUploading(profile: profile),
          ProfileUpdateSuccess(
            profile: profile.copyWith(
              avatarUrl: 'https://example.com/new-avatar.png',
            ),
          ),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'emits ProfileFailure on failure',
        build: () {
          when(
            () => mocks.profile.uploadAvatar(
              profileId: profileId,
              bytes: any(named: 'bytes'),
              contentType: any(named: 'contentType'),
            ),
          ).thenThrow(Exception('error'));
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.uploadAvatar(
          profileId: profileId,
          bytes: bytes,
          contentType: contentType,
        ),
        expect: () => [
          AvatarUploading(profile: profile),
          const ProfileFailure(message: 'Не удалось загрузить аватар.'),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'works when state is ProfileUpdateSuccess',
        build: () {
          when(
            () => mocks.profile.uploadAvatar(
              profileId: profileId,
              bytes: any(named: 'bytes'),
              contentType: any(named: 'contentType'),
            ),
          ).thenAnswer((_) async => 'https://example.com/new-avatar.png');
          return createCubit();
        },
        seed: () => ProfileUpdateSuccess(profile: profile),
        act: (cubit) => cubit.uploadAvatar(
          profileId: profileId,
          bytes: bytes,
          contentType: contentType,
        ),
        expect: () => [
          AvatarUploading(profile: profile),
          ProfileUpdateSuccess(
            profile: profile.copyWith(
              avatarUrl: 'https://example.com/new-avatar.png',
            ),
          ),
        ],
      );
    });

    group('removeAvatar()', () {
      blocTest<ProfileCubit, ProfileState>(
        'emits [AvatarUploading, ProfileUpdateSuccess] from ProfileLoaded',
        build: () {
          when(() => mocks.profile.removeAvatar(profileId))
              .thenAnswer((_) async {});
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.removeAvatar(profileId),
        expect: () => [
          AvatarUploading(profile: profile),
          ProfileUpdateSuccess(
            profile: profile.copyWith(clearAvatar: true),
          ),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'removeAvatar from ProfileUpdateSuccess state (else branch)',
        build: () {
          when(() => mocks.profile.removeAvatar(profileId))
              .thenAnswer((_) async {});
          return createCubit();
        },
        seed: () => ProfileUpdateSuccess(profile: profile),
        act: (cubit) => cubit.removeAvatar(profileId),
        expect: () => [
          AvatarUploading(profile: profile),
          ProfileUpdateSuccess(
            profile: profile.copyWith(clearAvatar: true),
          ),
        ],
      );

      blocTest<ProfileCubit, ProfileState>(
        'removeAvatar emits failure on exception',
        build: () {
          when(() => mocks.profile.removeAvatar(profileId))
              .thenThrow(Exception('error'));
          return createCubit();
        },
        seed: () => ProfileLoaded(profile: profile),
        act: (cubit) => cubit.removeAvatar(profileId),
        expect: () => [
          AvatarUploading(profile: profile),
          const ProfileFailure(message: 'Не удалось удалить аватар.'),
        ],
      );
    });

    group('getStats()', () {
      test('delegates to use case and returns ProfileStats', () async {
        const stats = ProfileStats(
          totalAssigned: 10,
          completedTasks: 7,
          completedThisMonth: 3,
          completedThisWeek: 1,
        );
        when(() => mocks.profile.getStats(profileId))
            .thenAnswer((_) async => stats);

        final cubit = createCubit();
        final result = await cubit.getStats(profileId);

        expect(result, stats);
        verify(() => mocks.profile.getStats(profileId)).called(1);
      });
    });

    group('uploadAvatar from ProfileLoaded with null avatarUrl then removeAvatar', () {
      blocTest<ProfileCubit, ProfileState>(
        'removeAvatar works after upload changes avatarUrl',
        build: () {
          when(() => mocks.profile.removeAvatar(profileId))
              .thenAnswer((_) async {});
          return createCubit();
        },
        seed: () => ProfileUpdateSuccess(profile: profile.copyWith(avatarUrl: 'https://new.url')),
        act: (cubit) => cubit.removeAvatar(profileId),
        expect: () => [
          AvatarUploading(profile: profile.copyWith(avatarUrl: 'https://new.url')),
          ProfileUpdateSuccess(
            profile: profile.copyWith(clearAvatar: true),
          ),
        ],
      );
    });

    test('removeAvatar with no profile state returns early (currentProfile == null)', () async {
      final cubit = createCubit();
      // state is ProfileInitial — no profile to remove
      await cubit.removeAvatar(profileId);
      verifyNever(() => mocks.profile.removeAvatar(any()));
    });
  });
}
