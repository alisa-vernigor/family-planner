import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/household.dart';
import '../../domain/entities/household_invitation.dart';
import '../../domain/entities/household_member.dart';
import '../../domain/repositories/household_repository.dart';

final class SupabaseHouseholdRepository implements HouseholdRepository {
  SupabaseHouseholdRepository({required this._client});

  final SupabaseClient _client;

  @override
  Future<List<Household>> getMyHouseholds() async {
    final rows = await _client
        .from('household_members')
        .select('households(id, name)')
        .order('joined_at');

    return rows
        .map((row) {
          final household = row['households'] as Map<String, dynamic>;

          return Household(
            id: household['id'] as String,
            name: household['name'] as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Household> create({required String name}) async {
    final row =
        await _client.rpc('create_household', params: {'household_name': name})
            as Map<String, dynamic>;

    return Household(id: row['id'] as String, name: row['name'] as String);
  }

  @override
  Future<List<HouseholdMember>> getMembers({
    required String householdId,
  }) async {
    final rows = await _client
        .from('household_members')
        .select('profile_id, role, profiles(display_name)')
        .eq('household_id', householdId)
        .order('joined_at');

    return rows
        .map((row) {
          final profile = row['profiles'] as Map<String, dynamic>;

          return HouseholdMember(
            profileId: row['profile_id'] as String,
            displayName: profile['display_name'] as String,
            role: row['role'] as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createInvitation({
    required String householdId,
    required String email,
  }) async {
    await _client.rpc(
      'create_household_invitation',
      params: {
        'p_household_id': householdId,
        'p_email': email.trim().toLowerCase(),
      },
    );
  }

  @override
  Future<List<HouseholdInvitation>> getPendingInvitations() async {
    final rows = await _client
        .from('household_invitations')
        .select(
          'id, household_id, created_at, expires_at, '
          'households(name), '
          'profiles!household_invitations_invited_by_profile_id_fkey('
          'display_name'
          ')',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows
        .map((row) {
          final household = row['households'] as Map<String, dynamic>;
          final inviter = row['profiles'] as Map<String, dynamic>;

          return HouseholdInvitation(
            id: row['id'] as String,
            householdId: row['household_id'] as String,
            householdName: household['name'] as String,
            invitedByDisplayName: inviter['display_name'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            expiresAt: DateTime.parse(row['expires_at'] as String),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<String> acceptInvitation({required String invitationId}) async {
    return await _client.rpc(
          'accept_household_invitation',
          params: {'p_invitation_id': invitationId},
        )
        as String;
  }

  @override
  Future<void> declineInvitation({required String invitationId}) async {
    await _client.rpc(
      'decline_household_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }
}
