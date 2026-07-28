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

    final seen = <String>{};

    return rows
        .map((row) {
          final household = row['households'] as Map<String, dynamic>;

          return Household(
            id: household['id'] as String,
            name: household['name'] as String,
          );
        })
        .where((h) => seen.add(h.id))
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
        .select('profile_id, role, profiles(display_name, avatar_url)')
        .eq('household_id', householdId)
        .order('joined_at');

    return rows
        .map((row) {
          final profile = row['profiles'] as Map<String, dynamic>;

          return HouseholdMember(
            profileId: row['profile_id'] as String,
            displayName: profile['display_name'] as String,
            avatarUrl: profile['avatar_url'] as String?,
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
    final currentUserId = _client.auth.currentUser?.id;

    var query = _client
        .from('household_invitations')
        .select(
          'id, household_id, created_at, expires_at, invited_by_profile_id, '
          'profiles!household_invitations_invited_by_profile_id_fkey('
          'display_name'
          ')',
        )
        .eq('status', 'pending');

    if (currentUserId != null) {
      query = query.neq('invited_by_profile_id', currentUserId);
    }

    final rows = await query.order('created_at', ascending: false);

    if (rows.isEmpty) return [];

    final householdIds =
        rows.map((r) => r['household_id'] as String).toSet().toList();

    // Единый запрос вместо N+1 RPC вызовов
    final nameMap = <String, String>{};
    if (householdIds.isNotEmpty) {
      final householdRows = await _client
          .from('households')
          .select('id, name')
          .inFilter('id', householdIds);
      for (final h in householdRows) {
        nameMap[h['id'] as String] = h['name'] as String;
      }
    }

    return rows
        .map((row) {
          final inviter = row['profiles'] as Map<String, dynamic>?;

          return HouseholdInvitation(
            id: row['id'] as String,
            householdId: row['household_id'] as String,
            householdName:
                nameMap[row['household_id'] as String] ?? 'Неизвестная семья',
            invitedByDisplayName:
                inviter?['display_name'] as String? ?? 'Неизвестный',
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

  @override
  Future<void> leaveHousehold({required String householdId}) async {
    await _client.rpc(
      'leave_household',
      params: {'p_household_id': householdId},
    );
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {
    await _client.rpc(
      'remove_household_member',
      params: {
        'p_household_id': householdId,
        'p_profile_id': profileId,
      },
    );
  }

  @override
  Future<void> deleteHousehold({required String householdId}) async {
    await _client.rpc(
      'delete_household',
      params: {'p_household_id': householdId},
    );
  }

  @override
  Future<void> updateHousehold({
    required String householdId,
    required String name,
  }) async {
    await _client.rpc(
      'update_household_name',
      params: {
        'p_household_id': householdId,
        'p_name': name.trim(),
      },
    );
  }
}
