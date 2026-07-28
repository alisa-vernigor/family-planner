import 'package:equatable/equatable.dart';

final class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.timezone,
    this.bio = '',
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String timezone;
  final String bio;

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? timezone,
    String? bio,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      timezone: timezone ?? this.timezone,
      bio: bio ?? this.bio,
    );
  }

  @override
  List<Object?> get props => [id, displayName, avatarUrl, timezone, bio];
}
