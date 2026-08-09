import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/presentation/widgets/recurrence_summary.dart';

void main() {
  Widget buildSubject({
    TaskRecurrenceType type = TaskRecurrenceType.daily,
    int intervalDays = 1,
    int weekdayCount = 0,
    List<int> weekdays = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RecurrenceSummary(
          type: type,
          intervalDays: intervalDays,
          weekdayCount: weekdayCount,
          weekdays: weekdays,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  testWidgets('daily: «Каждый день» без дат и без предпросмотра', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Каждый день'), findsOneWidget);
    expect(find.byIcon(Icons.checklist), findsNothing);
  });

  testWidgets('weekly без дней: «Каждую неделю»', (tester) async {
    await tester.pumpWidget(buildSubject(type: TaskRecurrenceType.weekly));

    expect(find.text('Каждую неделю'), findsOneWidget);
  });

  testWidgets('weekly с днями: перечисляет дни недели', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        type: TaskRecurrenceType.weekly,
        weekdays: const [1, 3, 5],
      ),
    );

    expect(find.text('По пн, ср, пт'), findsOneWidget);
  });

  testWidgets('intervalDays: «Каждые N дн.»', (tester) async {
    await tester.pumpWidget(
      buildSubject(type: TaskRecurrenceType.intervalDays, intervalDays: 3),
    );

    expect(find.text('Каждые 3 дн.'), findsOneWidget);
  });

  testWidgets('с датами добавляет «с … по …» и считает количество', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 3),
      ),
    );

    expect(find.textContaining('с 1.8.2026 по 3.8.2026'), findsOneWidget);
    // 3 дня ежедневного повтора.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('weekly с датами считает количество совпавших дней недели', (
    tester,
  ) async {
    // 1.8.2026 — суббота (6), 2.8 — воскресенье (7), 3.8 — понедельник (1).
    await tester.pumpWidget(
      buildSubject(
        type: TaskRecurrenceType.weekly,
        weekdays: const [1],
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 3),
      ),
    );

    expect(find.textContaining('По пн'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('intervalDays с датами считает количество итераций', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        type: TaskRecurrenceType.intervalDays,
        intervalDays: 2,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
      ),
    );

    // days = 5, 5 ~/ 2 + 1 = 3.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('без endDate количество не показывается', (tester) async {
    await tester.pumpWidget(
      buildSubject(startDate: DateTime(2026, 8, 1)),
    );

    expect(find.textContaining('с 1.8.2026'), findsOneWidget);
  });

  testWidgets('с датами показывает предпросмотр первых 5 дат', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 10),
      ),
    );

    // Ежедневный повтор: 1,2,3,4,5 августа в предпросмотре.
    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('02.08.2026'), findsOneWidget);
    expect(find.text('05.08.2026'), findsOneWidget);
    expect(find.text('06.08.2026'), findsNothing);
    // Счётчик «…и ещё N».
    expect(find.text('…и ещё 5'), findsOneWidget);
  });

  testWidgets('intervalDays с датами генерирует предпросмотр по интервалу', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        type: TaskRecurrenceType.intervalDays,
        intervalDays: 3,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 20),
      ),
    );

    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('04.08.2026'), findsOneWidget);
    expect(find.text('07.08.2026'), findsOneWidget);
  });

  testWidgets('weekly предпросмотр включает только выбранные дни', (
    tester,
  ) async {
    // 1.8.2026 — суббота (6), 2.8 — вс (7), 3.8 — пн (1), 4.8 — вт (2).
    await tester.pumpWidget(
      buildSubject(
        type: TaskRecurrenceType.weekly,
        weekdays: const [6],
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 10),
      ),
    );

    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('08.08.2026'), findsOneWidget);
    expect(find.text('03.08.2026'), findsNothing);
  });

  testWidgets('startDate без конца — предпросмотр на 60 дней', (tester) async {
    await tester.pumpWidget(
      buildSubject(startDate: DateTime(2026, 8, 1)),
    );

    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('02.08.2026'), findsOneWidget);
    // 5 дат в предпросмотре.
    expect(find.byIcon(Icons.checklist), findsNWidgets(5));
  });

  testWidgets('без startDate — без предпросмотра и счётчика', (tester) async {
    await tester.pumpWidget(
      buildSubject(endDate: DateTime(2026, 8, 10)),
    );

    expect(find.text('Каждый день'), findsOneWidget);
    expect(find.byIcon(Icons.checklist), findsNothing);
  });
}
