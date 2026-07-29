import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';

import 'household_invitations_state.dart';

final class HouseholdInvitationsCubit extends Cubit<HouseholdInvitationsState> {
  HouseholdInvitationsCubit({
    required this.householdRepository,
  }) : super(const HouseholdInvitationsInitial());

  final HouseholdRepository householdRepository;

  Future<void> load() async {
    emit(const HouseholdInvitationsLoading());

    try {
      final invitations = await householdRepository.getPendingInvitations();

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
      final householdId = await householdRepository.acceptInvitation(
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
      await householdRepository.declineInvitation(invitationId: invitation.id);

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
