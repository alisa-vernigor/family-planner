import 'package:equatable/equatable.dart';

final class HouseholdMember extends Equatable {
  const HouseholdMember({
    required this.profileId,
    required this.displayName,
    required this.role,
  });

  final String profileId;
  final String displayName;
  final String role;

  bool get isOwner => role == 'owner';

  @override
  List<Object?> get props => [profileId, displayName, role];
}
