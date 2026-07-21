import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_household_members_use_case.dart';

import 'household_members_state.dart';

final class HouseholdMembersCubit extends Cubit<HouseholdMembersState> {
  HouseholdMembersCubit({
    required this.getHouseholdMembersUseCase,
    required this.createHouseholdInvitationUseCase,
  }) : super(const HouseholdMembersInitial());

  final GetHouseholdMembersUseCase getHouseholdMembersUseCase;
  final CreateHouseholdInvitationUseCase createHouseholdInvitationUseCase;

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
