import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/use_cases/add_household_member_by_email_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';

import 'household_members_state.dart';

final class HouseholdMembersCubit extends Cubit<HouseholdMembersState> {
  HouseholdMembersCubit({
    required this.addHouseholdMemberByEmailUseCase,
    required this.getHouseholdMembersUseCase,
  }) : super(const HouseholdMembersInitial());

  final AddHouseholdMemberByEmailUseCase addHouseholdMemberByEmailUseCase;
  final GetHouseholdMembersUseCase getHouseholdMembersUseCase;

  Future<void> load({required String householdId}) async {
    emit(const HouseholdMembersLoading());

    try {
      final members = await getHouseholdMembersUseCase(
        householdId: householdId,
      );

      emit(HouseholdMembersLoaded(members: members));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось загрузить участников семьи.',
      );
    }
  }

  Future<void> addByEmail({
    required String householdId,
    required String email,
  }) async {
    final List<HouseholdMember> existingMembers = switch (state) {
      HouseholdMembersLoaded(:final members) => members,
      HouseholdMemberAdded(:final members) => members,
      HouseholdMemberAdding(:final members) => members,
      _ => const <HouseholdMember>[],
    };

    emit(HouseholdMemberAdding(members: existingMembers));

    try {
      final member = await addHouseholdMemberByEmailUseCase(
        householdId: householdId,
        email: email,
      );

      final updatedMembers = [
        ...existingMembers.where(
          (existingMember) => existingMember.profileId != member.profileId,
        ),
        member,
      ];

      AppLogger.info(
        'Участник добавлен в семью: '
        'householdId=$householdId; profileId=${member.profileId}',
      );

      emit(HouseholdMemberAdded(members: updatedMembers, addedMember: member));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось добавить участника в семью.',
      );
    }
  }

  void _emitFailure({
    required Object exception,
    required StackTrace stackTrace,
    required String message,
  }) {
    AppLogger.error(message, error: exception, stackTrace: stackTrace);

    emit(HouseholdMembersFailure(message: message));
  }
}
