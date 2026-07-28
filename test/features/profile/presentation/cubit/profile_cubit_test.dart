import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore_for_file: prefer_const_constructors

import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_stats_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/remove_avatar_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/upload_avatar_use_case.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_state.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late GetProfileUseCase getProfileUseCase;
  late UpdateProfileUseCase updateProfileUseCase;
  late UploadAvatarUseCase uploadAvatarUseCase;
  late RemoveAvatarUseCase removeAvatarUseCase;
  late GetProfileStatsUseCase getProfileStatsUseCase;

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
    repository = _MockProfileRepository();
    getProfileUseCase = GetProfileUseCase(repository: repository);
    updateProfileUseCase = UpdateProfileUseCase(repository: repository);
    uploadAvatarUseCase = UploadAvatarUseCase(repository: repository);
    removeAvatarUseCase = RemoveAvatarUseCase(repository: repository);
    getProfileStatsUseCase = GetProfileStatsUseCase(repository: repository);
    registerFallbackValue(Uint8List(0));
  });

  ProfileCubit createCubit() {
    return ProfileCubit(
      getProfileUseCase: getProfileUseCase,
      updateProfileUseCase: updateProfileUseCase,
      uploadAvatarUseCase: uploadAvatarUseCase,
      removeAvatarUseCase: removeAvatarUseCase,
      getProfileStatsUseCase: getProfileStatsUseCase,
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
          when(() => repository.getProfile(profileId))
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
          when(() => repository.getProfile(profileId))
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
            () => repository.updateProfile(
              profileId: profileId,
              displayName: any(named: 'displayName'),
              bio: any(named: 'bio'),
              timezone: any(named: 'timezone'),
            ),
          ).thenAnswer((_) async {});
          when(() => repository.getProfile(profileId))
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
            () => repository.updateProfile(
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
            () => repository.updateProfile(
              profileId: profileId,
              displayName: 'Bob',
              bio: any(named: 'bio'),
              timezone: any(named: 'timezone'),
            ),
          ).thenAnswer((_) async {});
          when(() => repository.getProfile(profileId))
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
            () => repository.uploadAvatar(
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
            () => repository.uploadAvatar(
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
            () => repository.uploadAvatar(
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
          when(() => repository.removeAvatar(profileId))
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
          when(() => repository.removeAvatar(profileId))
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
          when(() => repository.removeAvatar(profileId))
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
        when(() => repository.getStats(profileId))
            .thenAnswer((_) async => stats);

        final cubit = createCubit();
        final result = await cubit.getStats(profileId);

        expect(result, stats);
        verify(() => repository.getStats(profileId)).called(1);
      });
    });

    group('uploadAvatar from ProfileLoaded with null avatarUrl then removeAvatar', () {
      blocTest<ProfileCubit, ProfileState>(
        'removeAvatar works after upload changes avatarUrl',
        build: () {
          when(() => repository.removeAvatar(profileId))
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
      verifyNever(() => repository.removeAvatar(any()));
    });
  });
}
