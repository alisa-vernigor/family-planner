import 'dart:typed_data';

import '../entities/profile_stats.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getProfile(String profileId);

  Future<void> updateProfile({
    required String profileId,
    String? displayName,
    String? bio,
    String? timezone,
  });

  /// Upload avatar image. Returns the public URL.
  Future<String> uploadAvatar({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  });

  /// Remove the current avatar image.
  Future<void> removeAvatar(String profileId);

  /// Get task statistics for a profile (only visible to household members).
  Future<ProfileStats> getStats(String profileId);
}
