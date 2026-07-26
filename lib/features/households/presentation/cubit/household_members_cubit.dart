import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/leave_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/remove_household_member_use_case.dart';

import 'household_members_state.dart';

final class HouseholdMembersCubit extends Cubit<HouseholdMembersState> {
  HouseholdMembersCubit({
    required this.getHouseholdMembersUseCase,
    required this.createHouseholdInvitationUseCase,
    required this.leaveHouseholdUseCase,
    required this.removeHouseholdMemberUseCase,
  }) : super(const HouseholdMembersInitial());

  final GetHouseholdMembersUseCase getHouseholdMembersUseCase;
  final CreateHouseholdInvitationUseCase createHouseholdInvitationUseCase;
  final LeaveHouseholdUseCase leaveHouseholdUseCase;
  final RemoveHouseholdMemberUseCase removeHouseholdMemberUseCase;

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

  Future<void> inviteByEmail({
    required String householdId,
    required String email,
  }) async {
    final members = _currentMembers;

    emit(HouseholdInvitationSending(members: members));

    try {
      await createHouseholdInvitationUseCase(
        householdId: householdId,
        email: email,
      );

      AppLogger.info(
        'Приглашение в семью отправлено: householdId=$householdId',
      );

      emit(HouseholdInvitationSent(members: members));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось отправить приглашение.',
      );
    }
  }

  Future<void> leaveHousehold({required String householdId}) async {
    try {
      await leaveHouseholdUseCase(householdId: householdId);

      AppLogger.info('Выход из семьи: householdId=$householdId');
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось выйти из семьи.',
      );
    }
  }

  Future<void> removeMember({
    required String householdId,
    required String profileId,
  }) async {
    final members = _currentMembers;

    try {
      await removeHouseholdMemberUseCase(
        householdId: householdId,
        profileId: profileId,
      );

      AppLogger.info('Участник удалён: profileId=$profileId');

      final updated = members.where((m) => m.profileId != profileId).toList();
      emit(HouseholdMembersLoaded(members: updated));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось удалить участника.',
      );
    }
  }

  List<HouseholdMember> get _currentMembers {
    return switch (state) {
      HouseholdMembersLoaded(:final members) => members,
      HouseholdInvitationSending(:final members) => members,
      HouseholdInvitationSent(:final members) => members,
      _ => const <HouseholdMember>[],
    };
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
