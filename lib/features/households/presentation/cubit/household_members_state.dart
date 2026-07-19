import 'package:equatable/equatable.dart';

import '../../domain/entities/household_member.dart';

sealed class HouseholdMembersState extends Equatable {
  const HouseholdMembersState();

  @override
  List<Object?> get props => [];
}

final class HouseholdMembersInitial extends HouseholdMembersState {
  const HouseholdMembersInitial();
}

final class HouseholdMembersLoading extends HouseholdMembersState {
  const HouseholdMembersLoading();
}

final class HouseholdMembersLoaded extends HouseholdMembersState {
  const HouseholdMembersLoaded({required this.members});

  final List<HouseholdMember> members;

  @override
  List<Object?> get props => [members];
}

final class HouseholdMembersFailure extends HouseholdMembersState {
  const HouseholdMembersFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

final class HouseholdMemberAdding extends HouseholdMembersState {
  const HouseholdMemberAdding({required this.members});

  final List<HouseholdMember> members;

  @override
  List<Object?> get props => [members];
}

final class HouseholdMemberAdded extends HouseholdMembersState {
  const HouseholdMemberAdded({
    required this.members,
    required this.addedMember,
  });

  final List<HouseholdMember> members;
  final HouseholdMember addedMember;

  @override
  List<Object?> get props => [members, addedMember];
}
