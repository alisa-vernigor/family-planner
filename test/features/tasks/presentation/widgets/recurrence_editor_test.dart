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

    testWidgets('intervalDays-повтор: поле N дней и значение в onChanged', (
      tester,
    ) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(onChanged: (draft) => lastDraft = draft),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Раз в несколько дней').last);
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('recurrence_interval_field'));
      expect(field, findsOneWidget);

      await tester.enterText(field, '5');
      await tester.pumpAndSettle();

      final recurrence = lastDraft?.buildRecurrence();
      expect(recurrence, isA<TaskRecurrence>());
      expect(recurrence!.intervalDays, 5);
    });

    testWidgets('start date: выбор даты отдаёт startDate через onChanged', (
      tester,
    ) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(onChanged: (draft) => lastDraft = draft),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('recurrence_start_date_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_start_date_button')));
      await tester.pumpAndSettle();

      // Дата-пикер открылся.
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Выбираем первый день месяца и подтверждаем кнопкой OK
      // (Material 3: тап по дню лишь подсвечивает его).
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('OK').last);
      await tester.pumpAndSettle();

      expect(lastDraft?.startDate, isNotNull);
      // Появляется кнопка очистки.
      await tester.ensureVisible(find.byKey(const Key('clear_recurrence_start_date_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clear_recurrence_start_date_button')), findsOneWidget);

      // Очищаем.
      await tester.tap(find.byKey(const Key('clear_recurrence_start_date_button')));
      await tester.pumpAndSettle();
      expect(lastDraft?.startDate, isNull);
    });

    testWidgets('end date: выбор даты и очистка', (tester) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(onChanged: (draft) => lastDraft = draft),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('recurrence_end_date_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_end_date_button')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('OK').last);
      await tester.pumpAndSettle();

      expect(lastDraft?.endDate, isNotNull);

      await tester.ensureVisible(find.byKey(const Key('clear_recurrence_end_date_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear_recurrence_end_date_button')));
      await tester.pumpAndSettle();
      expect(lastDraft?.endDate, isNull);
    });

    testWidgets('отмена в дата-пикере не меняет состояние', (tester) async {
      RecurrenceDraft? lastDraft;
      await tester.pumpWidget(
        buildSubject(onChanged: (draft) => lastDraft = draft),
      );

      await tester.tap(find.byKey(const Key('recurrence_switch')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('recurrence_start_date_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recurrence_start_date_button')));
      await tester.pumpAndSettle();

      // В Material 3 дата-пикере кнопка отмены называется Cancel (англ.).
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(lastDraft?.startDate, isNull);
    });
  });

  group('RecurrenceDraft', () {
    test('buildRecurrence возвращает null при выключенном повторе', () {
      const draft = RecurrenceDraft(
        type: TaskRecurrenceType.daily,
        isEnabled: false,
      );
      expect(draft.buildRecurrence(), isNull);
    });

    test('buildRecurrence: weekly сортирует weekdays', () {
      const draft = RecurrenceDraft(
        type: TaskRecurrenceType.weekly,
        isEnabled: true,
        weekdays: [5, 1, 3],
      );
      final recurrence = draft.buildRecurrence();
      expect(recurrence, isA<TaskRecurrence>());
      expect(recurrence!.weekdays, [1, 3, 5]);
    });

    test('buildRecurrence: intervalDays сохраняет interval', () {
      const draft = RecurrenceDraft(
        type: TaskRecurrenceType.intervalDays,
        isEnabled: true,
        intervalDays: 7,
      );
      expect(draft.buildRecurrence(), isA<TaskRecurrence>());
      expect(draft.buildRecurrence()!.intervalDays, 7);
    });

    test('copyWith меняет поля и сбрасывает nullable даты', () {
      final draft = RecurrenceDraft(
        type: TaskRecurrenceType.daily,
        isEnabled: true,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 9, 1),
      );

      final changed = draft.copyWith(
        type: TaskRecurrenceType.weekly,
        isEnabled: false,
        intervalDays: 3,
        weekdays: const [1],
        startDate: null,
        endDate: null,
      );

      expect(changed.type, TaskRecurrenceType.weekly);
      expect(changed.isEnabled, isFalse);
      expect(changed.intervalDays, 3);
      expect(changed.weekdays, [1]);
      expect(changed.startDate, isNull);
      expect(changed.endDate, isNull);

      // Неизменённые поля остаются.
      final partial = draft.copyWith(intervalDays: 10);
      expect(partial.type, TaskRecurrenceType.daily);
      expect(partial.startDate, DateTime(2026, 8, 1));
    });

    test('equatable учитывает все поля', () {
      const a = RecurrenceDraft(type: TaskRecurrenceType.daily, isEnabled: true);
      const b = RecurrenceDraft(type: TaskRecurrenceType.daily, isEnabled: true);
      const c = RecurrenceDraft(type: TaskRecurrenceType.weekly, isEnabled: true);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
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
