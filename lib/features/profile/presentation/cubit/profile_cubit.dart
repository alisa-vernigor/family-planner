import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';

import 'profile_state.dart';

final class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.profileRepository,
  }) : super(const ProfileInitial());

  final ProfileRepository profileRepository;

  Future<void> load(String profileId) async {
    emit(const ProfileLoading());

    try {
      final profile = await profileRepository.getProfile(profileId);
      emit(ProfileLoaded(profile: profile));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить профиль.';
      AppLogger.error(message, error: exception, stackTrace: stackTrace);
      emit(ProfileFailure(message: message));
    }
  }

  Future<void> updateProfile({
    required String profileId,
    String? displayName,
    String? bio,
  }) async {
    final current = state;
    if (current case ProfileLoaded(:final profile)) {
      // Optimistic update
      final updated = profile.copyWith(
        displayName: displayName,
        bio: bio,
      );
      emit(ProfileUpdateSuccess(profile: updated));
    }

    try {
      await profileRepository.updateProfile(
        profileId: profileId,
        displayName: displayName,
        bio: bio,
      );
      // Reload fresh data
      final profile = await profileRepository.getProfile(profileId);
      emit(ProfileLoaded(profile: profile));
    } catch (exception, stackTrace) {
      const message = 'Не удалось обновить профиль.';
      AppLogger.error(message, error: exception, stackTrace: stackTrace);
      emit(ProfileFailure(message: message));
    }
  }

  Future<void> uploadAvatar({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final current = state;
    UserProfile? currentProfile;
    if (current case ProfileLoaded(:final profile)) {
      currentProfile = profile;
      emit(AvatarUploading(profile: profile));
    } else if (current case ProfileUpdateSuccess(:final profile)) {
      currentProfile = profile;
      emit(AvatarUploading(profile: profile));
    }

    if (currentProfile == null) return;

    try {
      final url = await profileRepository.uploadAvatar(
        profileId: profileId,
        bytes: bytes,
        contentType: contentType,
      );

      final updated = currentProfile.copyWith(avatarUrl: url);
      emit(ProfileUpdateSuccess(profile: updated));
    } catch (exception, stackTrace) {
      const message = 'Не удалось загрузить аватар.';
      AppLogger.error(message, error: exception, stackTrace: stackTrace);
      emit(ProfileFailure(message: message));
    }
  }

  Future<void> removeAvatar(String profileId) async {
    final current = state;
    UserProfile? currentProfile;
    if (current case ProfileLoaded(:final profile)) {
      currentProfile = profile;
      emit(AvatarUploading(profile: profile));
    } else if (current case ProfileUpdateSuccess(:final profile)) {
      currentProfile = profile;
      emit(AvatarUploading(profile: profile));
    }

    if (currentProfile == null) return;

    try {
      await profileRepository.removeAvatar(profileId);

      final updated = currentProfile.copyWith(clearAvatar: true);
      emit(ProfileUpdateSuccess(profile: updated));
    } catch (exception, stackTrace) {
      const message = 'Не удалось удалить аватар.';
      AppLogger.error(message, error: exception, stackTrace: stackTrace);
      emit(ProfileFailure(message: message));
    }
  }

  Future<ProfileStats> getStats(String profileId) async {
    return profileRepository.getStats(profileId);
  }
}
