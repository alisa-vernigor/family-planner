import 'package:flutter/material.dart';

import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';

/// A reusable avatar widget that shows either the profile image or initials.
final class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    required this.profile,
    this.radius = 20,
    this.onTap,
    super.key,
  });

  AvatarWidget.fromMember({
    required HouseholdMember member,
    this.radius = 20,
    this.onTap,
    super.key,
  }) : profile = UserProfile(
          id: member.profileId,
          displayName: member.displayName,
          avatarUrl: member.avatarUrl,
          timezone: 'Europe/Moscow',
        );

  /// Create from a URL string directly (for cached headers).
  AvatarWidget.url({
    this.radius = 20,
    this.onTap,
    required String? imageUrl,
    required String displayName,
    super.key,
  }) : profile = UserProfile(
          id: '',
          displayName: displayName,
          avatarUrl: imageUrl,
          timezone: 'Europe/Moscow',
        );

  final UserProfile profile;
  final double radius;
  final VoidCallback? onTap;

  String get _initials {
    if (profile.displayName.isEmpty) return '?';
    final parts = profile.displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return profile.displayName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget avatar;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(profile.avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: _initialCircle(cs),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: cs.primaryContainer,
        child: Text(
          _initials,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: radius * 0.7,
            color: cs.onPrimaryContainer,
          ),
        ),
      );
    }

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _initialCircle(ColorScheme cs) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        _initials,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
