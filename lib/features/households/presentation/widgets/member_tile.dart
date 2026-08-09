import 'package:flutter/material.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_page.dart';

/// Tile отображения участника семьи в списке.
///
/// Показывает аватар, имя, роль (владелец/участник). Владелец семьи
/// видит кнопку удаления для других участников.
final class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.member,
    required this.isOwner,
    required this.isCurrentUser,
    required this.onRemove,
    super.key,
  });

  final HouseholdMember member;
  final bool isOwner;
  final bool isCurrentUser;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            backgroundImage:
                member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                    ? NetworkImage(member.avatarUrl!)
                    : null,
            child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                ? Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'вы',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            member.isOwner ? 'Владелец семьи' : 'Участник',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (member.isOwner)
                Icon(Icons.workspace_premium_rounded, color: cs.primary)
              else if (isOwner)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: cs.error),
                  tooltip: 'Удалить участника',
                  onPressed: onRemove,
                )
              else
                Icon(Icons.person_outline, color: cs.onSurfaceVariant),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfilePage(
                  profileId: member.profileId,
                  displayName: member.displayName,
                  viewerId: isCurrentUser ? member.profileId : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
