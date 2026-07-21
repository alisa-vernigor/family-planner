import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/use_cases/accept_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/decline_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_pending_household_invitations_use_case.dart';

import 'household_invitations_state.dart';

final class HouseholdInvitationsCubit extends Cubit<HouseholdInvitationsState> {
  HouseholdInvitationsCubit({
    required this.getPendingHouseholdInvitationsUseCase,
    required this.acceptHouseholdInvitationUseCase,
    required this.declineHouseholdInvitationUseCase,
  }) : super(const HouseholdInvitationsInitial());

  final GetPendingHouseholdInvitationsUseCase
  getPendingHouseholdInvitationsUseCase;
  final AcceptHouseholdInvitationUseCase acceptHouseholdInvitationUseCase;
  final DeclineHouseholdInvitationUseCase declineHouseholdInvitationUseCase;

  Future<void> load() async {
    emit(const HouseholdInvitationsLoading());

    try {
      final invitations = await getPendingHouseholdInvitationsUseCase();

      emit(HouseholdInvitationsLoaded(invitations: invitations));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось загрузить приглашения.',
      );
    }
  }

  Future<String?> accept({required HouseholdInvitation invitation}) async {
    final invitations = _currentInvitations;

    emit(
      HouseholdInvitationActionInProgress(
        invitations: invitations,
        invitationId: invitation.id,
      ),
    );

    try {
      final householdId = await acceptHouseholdInvitationUseCase(
        invitationId: invitation.id,
      );

      final updatedInvitations = invitations
          .where((item) => item.id != invitation.id)
          .toList(growable: false);

      AppLogger.info(
        'Приглашение в семью принято: '
        'invitationId=${invitation.id}; householdId=$householdId',
      );

      emit(HouseholdInvitationsLoaded(invitations: updatedInvitations));

      return householdId;
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось принять приглашение.',
      );

      return null;
    }
  }

  Future<void> decline({required HouseholdInvitation invitation}) async {
    final invitations = _currentInvitations;

    emit(
      HouseholdInvitationActionInProgress(
        invitations: invitations,
        invitationId: invitation.id,
      ),
    );

    try {
      await declineHouseholdInvitationUseCase(invitationId: invitation.id);

      final updatedInvitations = invitations
          .where((item) => item.id != invitation.id)
          .toList(growable: false);

      AppLogger.info(
        'Приглашение в семью отклонено: invitationId=${invitation.id}',
      );

      emit(HouseholdInvitationsLoaded(invitations: updatedInvitations));
    } catch (exception, stackTrace) {
      _emitFailure(
        exception: exception,
        stackTrace: stackTrace,
        message: 'Не удалось отклонить приглашение.',
      );
    }
  }

  List<HouseholdInvitation> get _currentInvitations {
    return switch (state) {
      HouseholdInvitationsLoaded(:final invitations) => invitations,
      HouseholdInvitationActionInProgress(:final invitations) => invitations,
      _ => const <HouseholdInvitation>[],
    };
  }

  void _emitFailure({
    required Object exception,
    required StackTrace stackTrace,
    required String message,
  }) {
    AppLogger.error(message, error: exception, stackTrace: stackTrace);

    emit(HouseholdInvitationsFailure(message: message));
  }
}
