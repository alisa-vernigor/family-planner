import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/widgets/reschedule_picker.dart';

void main() {
  final baseTask = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Задача',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
  );

  final recurringTask = Task(
    id: 'task-2',
    householdId: 'household-1',
    title: 'Серия',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
    templateId: 'template-1',
    recurrence: const TaskRecurrence.daily(),
  );

  Widget buildSubject({
    required Task task,
    required ValueChanged<RescheduleResult?> onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showReschedulePicker(
                  context: context,
                  task: task,
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('обычная задача сразу открывает date picker', (tester) async {
    await tester.pumpWidget(buildSubject(task: baseTask, onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Перенести задачу'), findsOneWidget);
  });

  testWidgets('выбор даты возвращает RescheduleResult с newPlannedFor', (
    tester,
  ) async {
    RescheduleResult? result;
    await tester.pumpWidget(
      buildSubject(task: baseTask, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Подтверждаем выбранную дату в date picker.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isSeries, isFalse);
    expect(result!.newPlannedFor, isA<DateTime>());
  });

  testWidgets('отмена в date picker возвращает null', (tester) async {
    RescheduleResult? result = RescheduleResult(newPlannedFor: DateTime(2020));
    await tester.pumpWidget(
      buildSubject(task: baseTask, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('повторяющаяся задача показывает подтверждение серии', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(task: recurringTask, onResult: (_) {}),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Перенести серию?'), findsOneWidget);
    expect(
      find.text('Это повторяющаяся задача. Перенос изменит дату всей серии.'),
      findsOneWidget,
    );
  });

  testWidgets('подтверждение серии открывает date picker', (tester) async {
    RescheduleResult? result;
    await tester.pumpWidget(
      buildSubject(task: recurringTask, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();

    expect(find.text('Перенести задачу'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isSeries, isTrue);
  });

  testWidgets('отмена подтверждения серии возвращает null', (tester) async {
    RescheduleResult? result = RescheduleResult(newPlannedFor: DateTime(2020));
    await tester.pumpWidget(
      buildSubject(task: recurringTask, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
