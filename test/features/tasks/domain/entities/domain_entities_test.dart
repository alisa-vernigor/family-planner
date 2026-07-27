import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';

void main() {
  group('Household', () {
    test('создаётся с идентификатором и именем', () {
      const household = Household(id: 'h-1', name: 'Наша семья');

      expect(household.id, 'h-1');
      expect(household.name, 'Наша семья');
    });

    test('одинаковые Household равны', () {
      const a = Household(id: 'h-1', name: 'Наша семья');
      const b = Household(id: 'h-1', name: 'Наша семья');

      expect(a, equals(b));
    });

    test('разные Household не равны', () {
      const a = Household(id: 'h-1', name: 'Наша семья');
      const b = Household(id: 'h-2', name: 'Другая семья');

      expect(a, isNot(equals(b)));
    });
  });

  group('HouseholdInvitation', () {
    test('создаётся со всеми полями', () {
      final now = DateTime(2026, 7, 25, 12);

      final invitation = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
      );

      expect(invitation.id, 'inv-1');
      expect(invitation.householdId, 'h-1');
      expect(invitation.householdName, 'Наша семья');
      expect(invitation.invitedByDisplayName, 'Алиса');
      expect(invitation.createdAt, now);
      expect(invitation.expiresAt, now.add(const Duration(days: 7)));
    });

    test('одинаковые приглашения равны', () {
      final now = DateTime(2026, 7, 25);

      final a = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );
      final b = HouseholdInvitation(
        id: 'inv-1',
        householdId: 'h-1',
        householdName: 'Наша семья',
        invitedByDisplayName: 'Алиса',
        createdAt: now,
        expiresAt: now,
      );

      expect(a, equals(b));
    });
  });

  group('TaskRecurrence', () {
    test('daily создаётся с типом daily', () {
      const recurrence = TaskRecurrence.daily();

      expect(recurrence.type, TaskRecurrenceType.daily);
      expect(recurrence.intervalDays, isNull);
      expect(recurrence.weekdays, isEmpty);
    });

    test('weekly создаётся с переданными днями недели', () {
      const recurrence = TaskRecurrence.weekly(weekdays: [1, 3, 5]);

      expect(recurrence.type, TaskRecurrenceType.weekly);
      expect(recurrence.weekdays, [1, 3, 5]);
      expect(recurrence.intervalDays, isNull);
    });

    test('intervalDays создаётся с переданным интервалом', () {
      const recurrence = TaskRecurrence.intervalDays(intervalDays: 3);

      expect(recurrence.type, TaskRecurrenceType.intervalDays);
      expect(recurrence.intervalDays, 3);
      expect(recurrence.weekdays, isEmpty);
    });

    test('TaskRecurrenceType.databaseValue возвращает правильные строки', () {
      expect(TaskRecurrenceType.daily.databaseValue, 'daily');
      expect(TaskRecurrenceType.weekly.databaseValue, 'weekly');
      expect(TaskRecurrenceType.intervalDays.databaseValue, 'interval_days');
    });

    test('одинаковые объекты равны', () {
      const a = TaskRecurrence.weekly(weekdays: [1, 3]);
      const b = TaskRecurrence.weekly(weekdays: [1, 3]);

      expect(a, equals(b));
    });

    test('разные объекты не равны', () {
      const a = TaskRecurrence.daily();
      const b = TaskRecurrence.weekly(weekdays: [1]);

      expect(a, isNot(equals(b)));
    });
  });
}
