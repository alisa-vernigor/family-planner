import 'package:equatable/equatable.dart';

final class HouseholdInvitation extends Equatable {
  const HouseholdInvitation({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.invitedByDisplayName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String householdId;
  final String householdName;
  final String invitedByDisplayName;
  final DateTime createdAt;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    id,
    householdId,
    householdName,
    invitedByDisplayName,
    createdAt,
    expiresAt,
  ];
}
