import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/update_recurring_task_params.dart';
import 'package:family_planner/features/tasks/presentation/widgets/recurrence_edit_scope_dialog.dart';
import 'package:family_planner/features/tasks/presentation/widgets/recurrence_editor.dart';

void main() {
  group('RecurrenceEditor', () {
    Widget buildSubject({
      RecurrenceDraft? initial,
      ValueChanged<RecurrenceDraft>? onChanged,
      bool showEnableSwitch = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: RecurrenceEditor(
            initial: initial,
            showEnableSwitch: showEnableSwitch,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('показывает переключатель и скрывает детали по умолчанию', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const Key('recurrence_switch')), findsOneWidget);
      expect(find.byKey(const Key('recurrence_type_dropdown')), findsNothing);
      expect(find.byKey(const Key('weekday_chip_1')), findsNothing);
      expect(find.byKey(const Key('recurrence_interval_field')), findsNothing);
    });

    testWidgets('включает повторение и показывает тип + дни', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recurrence_type_dropdown')), findsOneWidget);

      // выбираем еженедельный повтор
      await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('В выбранные дни недели').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weekday_chip_1')), findsOneWidget);
    });

    testWidgets('в edit-режиме скрыт переключатель, но детали видны', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          initial: const RecurrenceDraft(
            type: TaskRecurrenceType.daily,
            isEnabled: true,
          ),
          showEnableSwitch: false,
        ),
      );

      expect(find.byKey(const Key('recurrence_switch')), findsNothing);
      expect(find.byKey(const Key('recurrence_type_dropdown')), findsOneWidget);
    });

    testWidgets('weekly-повтор с выбранными днями отдаёт их через onChanged', (
      tester,
    ) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(
          onChanged: (draft) => lastDraft = draft,
        ),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('В выбранные дни недели').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('weekday_chip_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekday_chip_1')));
      await tester.pumpAndSettle();

      final recurrence = lastDraft?.buildRecurrence();
      expect(recurrence, isA<TaskRecurrence>());
      expect(recurrence!.weekdays, contains(1));
    });

    testWidgets('выключенный повтор даёт buildRecurrence() == null', (
      tester,
    ) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(onChanged: (draft) => lastDraft = draft),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      expect(lastDraft?.buildRecurrence(), isNull);
    });
  });

  group('showRecurrenceEditScopeDialog', () {
    final task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Полить цветы',
      estimatedDurationMinutes: 10,
      plannedFor: DateTime(2026, 7, 19),
      allowedMemberIds: const ['user-1'],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 7, 19, 12),
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
    );

    testWidgets('показывает 3 опции и возвращает выбранную', (tester) async {
      RecurrenceEditScope? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showRecurrenceEditScopeDialog(
                      context: context,
                      task: task,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Только эту задачу'), findsOneWidget);
      expect(find.text('Эту и последующие'), findsOneWidget);
      expect(find.text('Все задачи в серии'), findsOneWidget);

      await tester.tap(find.text('Эту и последующие'));
      await tester.pumpAndSettle();

      expect(result, RecurrenceEditScope.thisAndFollowing);
    });

    testWidgets('отмена возвращает null', (tester) async {
      RecurrenceEditScope? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showRecurrenceEditScopeDialog(
                      context: context,
                      task: task,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
