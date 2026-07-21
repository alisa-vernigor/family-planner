import 'package:equatable/equatable.dart';

import '../../domain/entities/household_invitation.dart';

sealed class HouseholdInvitationsState extends Equatable {
  const HouseholdInvitationsState();

  @override
  List<Object?> get props => [];
}

final class HouseholdInvitationsInitial extends HouseholdInvitationsState {
  const HouseholdInvitationsInitial();
}

final class HouseholdInvitationsLoading extends HouseholdInvitationsState {
  const HouseholdInvitationsLoading();
}

final class HouseholdInvitationsLoaded extends HouseholdInvitationsState {
  const HouseholdInvitationsLoaded({required this.invitations});

  final List<HouseholdInvitation> invitations;

  @override
  List<Object?> get props => [invitations];
}

final class HouseholdInvitationActionInProgress
    extends HouseholdInvitationsState {
  const HouseholdInvitationActionInProgress({
    required this.invitations,
    required this.invitationId,
  });

  final List<HouseholdInvitation> invitations;
  final String invitationId;

  @override
  List<Object?> get props => [invitations, invitationId];
}

final class HouseholdInvitationsFailure extends HouseholdInvitationsState {
  const HouseholdInvitationsFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
