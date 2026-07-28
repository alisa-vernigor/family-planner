import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_stats_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/remove_avatar_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/upload_avatar_use_case.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repository;
  late GetProfileUseCase getProfileUseCase;
  late UpdateProfileUseCase updateProfileUseCase;
  late UploadAvatarUseCase uploadAvatarUseCase;
  late RemoveAvatarUseCase removeAvatarUseCase;
  late GetProfileStatsUseCase getProfileStatsUseCase;

  const profileId = 'profile-1';

  setUp(() {
    repository = _MockProfileRepository();
    getProfileUseCase = GetProfileUseCase(repository: repository);
    updateProfileUseCase = UpdateProfileUseCase(repository: repository);
    uploadAvatarUseCase = UploadAvatarUseCase(repository: repository);
    removeAvatarUseCase = RemoveAvatarUseCase(repository: repository);
    getProfileStatsUseCase = GetProfileStatsUseCase(repository: repository);
  });

  group('GetProfileUseCase', () {
    test('returns profile from repository', () async {
      final expected = UserProfile(
        id: profileId,
        displayName: 'Alice',
        timezone: 'Europe/Moscow',
      );
      when(() => repository.getProfile(profileId))
          .thenAnswer((_) async => expected);

      final result = await getProfileUseCase(profileId);

      expect(result, expected);
      verify(() => repository.getProfile(profileId)).called(1);
    });
  });

  group('UpdateProfileUseCase', () {
    test('calls repository.updateProfile with displayName', () async {
      when(
        () => repository.updateProfile(
          profileId: profileId,
          displayName: 'Bob',
          bio: null,
          timezone: null,
        ),
      ).thenAnswer((_) async {});

      await updateProfileUseCase(
        profileId: profileId,
        displayName: 'Bob',
      );

      verify(
        () => repository.updateProfile(
          profileId: profileId,
          displayName: 'Bob',
          bio: null,
          timezone: null,
        ),
      ).called(1);
    });

    test('calls repository.updateProfile with bio', () async {
      when(
        () => repository.updateProfile(
          profileId: profileId,
          displayName: null,
          bio: 'New bio',
          timezone: null,
        ),
      ).thenAnswer((_) async {});

      await updateProfileUseCase(
        profileId: profileId,
        bio: 'New bio',
      );

      verify(
        () => repository.updateProfile(
          profileId: profileId,
          displayName: null,
          bio: 'New bio',
          timezone: null,
        ),
      ).called(1);
    });
  });

  group('UploadAvatarUseCase', () {
    test('calls repository.uploadAvatar returns URL', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      const contentType = 'image/png';
      const expectedUrl = 'https://example.com/avatar.png';

      when(
        () => repository.uploadAvatar(
          profileId: profileId,
          bytes: bytes,
          contentType: contentType,
        ),
      ).thenAnswer((_) async => expectedUrl);

      final result = await uploadAvatarUseCase(
        profileId: profileId,
        bytes: bytes,
        contentType: contentType,
      );

      expect(result, expectedUrl);
      verify(
        () => repository.uploadAvatar(
          profileId: profileId,
          bytes: bytes,
          contentType: contentType,
        ),
      ).called(1);
    });
  });

  group('RemoveAvatarUseCase', () {
    test('calls repository.removeAvatar', () async {
      when(() => repository.removeAvatar(profileId))
          .thenAnswer((_) async {});

      await removeAvatarUseCase(profileId);

      verify(() => repository.removeAvatar(profileId)).called(1);
    });
  });

  group('GetProfileStatsUseCase', () {
    test('returns stats from repository', () async {
      final expected = const ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
        completedThisMonth: 3,
        completedThisWeek: 1,
      );
      when(() => repository.getStats(profileId))
          .thenAnswer((_) async => expected);

      final result = await getProfileStatsUseCase(profileId);

      expect(result, expected);
      verify(() => repository.getStats(profileId)).called(1);
    });
  });
}
