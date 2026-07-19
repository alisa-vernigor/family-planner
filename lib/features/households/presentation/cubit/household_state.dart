import 'package:equatable/equatable.dart';

import '../../domain/entities/household.dart';

sealed class HouseholdState extends Equatable {
  const HouseholdState();

  @override
  List<Object?> get props => [];
}

final class HouseholdInitial extends HouseholdState {
  const HouseholdInitial();
}

final class HouseholdLoading extends HouseholdState {
  const HouseholdLoading();
}

final class HouseholdEmpty extends HouseholdState {
  const HouseholdEmpty();
}

final class HouseholdLoaded extends HouseholdState {
  const HouseholdLoaded({required this.households});

  final List<Household> households;

  @override
  List<Object?> get props => [households];
}

final class HouseholdFailure extends HouseholdState {
  const HouseholdFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
