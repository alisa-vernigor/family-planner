import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/household_member.dart';
import '../../domain/entities/household.dart';
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
  Future<HouseholdMember> addMemberByEmail({
    required String householdId,
    required String email,
  }) async {
    final row =
        await _client.rpc(
              'add_household_member_by_email',
              params: {'p_household_id': householdId, 'p_email': email.trim()},
            )
            as Map<String, dynamic>;

    return HouseholdMember(
      profileId: row['profile_id'] as String,
      displayName: row['display_name'] as String,
      role: 'member',
    );
  }
}
