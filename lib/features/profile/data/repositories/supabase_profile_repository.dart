import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/profile_stats.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<UserProfile> getProfile(String profileId) async {
    final row = await _client
        .from('profiles')
        .select('id, display_name, avatar_url, timezone, bio')
        .eq('id', profileId)
        .single();

    return UserProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      timezone: row['timezone'] as String? ?? 'Europe/Moscow',
      bio: row['bio'] as String? ?? '',
    );
  }

  @override
  Future<void> updateProfile({
    required String profileId,
    String? displayName,
    String? bio,
    String? timezone,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (timezone != null) updates['timezone'] = timezone;

    if (updates.isEmpty) return;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', profileId);
  }

  @override
  Future<String> uploadAvatar({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Determine file extension from content type
    final ext = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'png',
    };

    final path = '$profileId/avatar.$ext';

    // Remove old avatar first
    await _removeExistingAvatar(profileId);

    // Upload new image
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );

    // Get public URL
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

    // Update profiles table
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', profileId);

    return publicUrl;
  }

  @override
  Future<void> removeAvatar(String profileId) async {
    await _removeExistingAvatar(profileId);

    await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', profileId);
  }

  Future<void> _removeExistingAvatar(String profileId) async {
    try {
      // List existing files in the user's folder
      final files = await _client.storage.from('avatars').list(path: profileId);

      for (final file in files) {
        await _client.storage.from('avatars').remove(['$profileId/${file.name}']);
      }
    } catch (e) {
      // Silently handle — no existing avatar is fine
      AppLogger.debug('No existing avatar to remove for $profileId');
    }
  }

  @override
  Future<ProfileStats> getStats(String profileId) async {
    try {
      final result = await _client.rpc(
        'get_profile_stats',
        params: {'p_profile_id': profileId},
      );

      if (result == null) {
        return const ProfileStats();
      }

      // Function returns TABLE, so result is a list of rows
      final rows = result as List<dynamic>;
      if (rows.isEmpty) {
        return const ProfileStats();
      }

      final data = rows.first as Map<String, dynamic>;

      return ProfileStats(
        totalAssigned: (data['total_assigned'] as num?)?.toInt() ?? 0,
        completedTasks: (data['completed_tasks'] as num?)?.toInt() ?? 0,
        completedThisMonth:
            (data['completed_this_month'] as num?)?.toInt() ?? 0,
        completedThisWeek:
            (data['completed_this_week'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      AppLogger.error('Failed to get profile stats', error: e);
      return const ProfileStats();
    }
  }
}
