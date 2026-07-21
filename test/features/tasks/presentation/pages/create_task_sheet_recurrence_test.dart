import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/pages/create_task_sheet.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) => CreateTaskCubit(
            createTaskUseCase: CreateTaskUseCase(
              repository: _FakeTaskRepository(),
            ),
          ),
          child: CreateTaskSheet(
            householdId: 'household-1',
            plannedFor: DateTime(2026, 7, 19),
          ),
        ),
      ),
    );
  }

  testWidgets('поля повторения скрыты до включения переключателя', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byKey(const Key('recurrence_switch')), findsOneWidget);
    expect(find.byKey(const Key('recurrence_type_dropdown')), findsNothing);
    expect(find.byKey(const Key('weekday_chip_1')), findsNothing);
    expect(find.byKey(const Key('recurrence_interval_field')), findsNothing);
  });

  testWidgets('после включения показывается выбор режима повторения', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurrence_type_dropdown')), findsOneWidget);
    expect(find.text('Каждый день'), findsOneWidget);
  });

  testWidgets('кнопки периода повтора появляются после включения', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recurrence_start_date_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recurrence_end_date_button')), findsOneWidget);
    expect(find.text('Начать повторение с даты задачи'), findsOneWidget);
    expect(find.text('Закончить повторение — без срока'), findsOneWidget);
  });

  testWidgets('можно выбрать день недели для еженедельного повтора', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('recurrence_switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recurrence_type_dropdown')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('В выбранные дни недели').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekday_chip_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('weekday_chip_1')));
    await tester.pump();

    final monday = tester.widget<FilterChip>(
      find.byKey(const Key('weekday_chip_1')),
    );

    expect(monday.selected, isTrue);
  });
}

final class _FakeTaskRepository implements TaskRepository {
  @override
  Future<Task> create({required CreateTaskParams params}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String taskId}) async {}

  @override
  Future<List<Task>> getForDay({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<List<Task>> getScheduledAfter({
    required String householdId,
    required DateTime day,
  }) async {
    return const [];
  }

  @override
  Future<void> save(Task task) async {}
}
