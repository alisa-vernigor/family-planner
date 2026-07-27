import 'package:flutter/material.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';

/// Shows a bottom sheet to pick a family member for assignment.
///
/// Returns the picked member's ID, or `''` for "no one" (unassign),
/// or `null` if cancelled.
Future<String?> showAssigneePicker({
  required BuildContext context,
  required List<HouseholdMember> members,
  String? currentAssigneeId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      return _AssigneePickerSheet(
        members: members,
        currentAssigneeId: currentAssigneeId,
      );
    },
  );
}

final class _AssigneePickerSheet extends StatelessWidget {
  const _AssigneePickerSheet({
    required this.members,
    this.currentAssigneeId,
  });

  final List<HouseholdMember> members;
  final String? currentAssigneeId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.person_add_outlined,
                      color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Назначить ответственного',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(Icons.person_off_outlined,
                    color: cs.onSurfaceVariant),
              ),
              title: const Text('Без ответственного'),
              selected: currentAssigneeId == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            const Divider(height: 1),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Нет участников для назначения',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...members.map((member) {
                final isSelected =
                    member.profileId == currentAssigneeId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(member.displayName),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: cs.primary)
                      : null,
                  selected: isSelected,
                  onTap: () =>
                      Navigator.of(context).pop(member.profileId),
                );
              }),
          ],
        ),
      ),
    );
  }
}
