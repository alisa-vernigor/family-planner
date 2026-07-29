import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';

import 'household_members_state.dart';

final class HouseholdMembersCubit extends Cubit<HouseholdMembersState> {
  HouseholdMembersCubit({
    required this.householdRepository,
  }) : super(const HouseholdMembersInitial());

  final HouseholdRepository householdRepository;

  Future<void> load({required String householdId}) async {
    emit(const HouseholdMembersLoading());

    try {
      final members = await householdRepository.getMembers(
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
      await householdRepository.createInvitation(
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

  Future<bool> leaveHousehold({required String householdId}) async {
    try {
      await householdRepository.leaveHousehold(householdId: householdId);

      AppLogger.info('Выход из семьи: householdId=$householdId');

      return true;
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось выйти из семьи.',
      );

      return false;
    }
  }

  Future<bool> removeMember({
    required String householdId,
    required String profileId,
  }) async {
    final members = _currentMembers;

    try {
      await householdRepository.removeMember(
        householdId: householdId,
        profileId: profileId,
      );

      AppLogger.info('Участник удалён: profileId=$profileId');

      final updated = members.where((m) => m.profileId != profileId).toList();
      emit(HouseholdMembersLoaded(members: updated));

      return true;
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось удалить участника.',
      );

      return false;
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
