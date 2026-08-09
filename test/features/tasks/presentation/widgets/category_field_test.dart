import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/presentation/widgets/category_field.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateTaskCategoryParams(householdId: 'h', name: 'n'),
    );
  });

  final categories = [
    const TaskCategory(
      id: 'cat-1',
      householdId: 'household-1',
      name: 'Покупки',
      colorHex: 'E53935',
    ),
    const TaskCategory(
      id: 'cat-2',
      householdId: 'household-1',
      name: 'Учёба',
      colorHex: '039BE5',
    ),
  ];

  Widget buildSubject({
    required MockTaskCategoryRepository repository,
    String? selectedCategoryId,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
    String householdId = 'household-1',
  }) {
    return RepositoryProvider<TaskCategoryRepository>(
      create: (_) => repository,
      child: MaterialApp(
        home: Scaffold(
          body: CategoryField(
            householdId: householdId,
            onChanged: onChanged ?? (_) {},
            selectedCategoryId: selectedCategoryId,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  testWidgets('показывает «Категория — необязательно» до выбора', (
    tester,
  ) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );

    await tester.pumpWidget(buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Категория — необязательно'), findsOneWidget);
  });

  testWidgets('показывает выбранную категорию цветным чипом', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );

    await tester.pumpWidget(
      buildSubject(repository: repository, selectedCategoryId: 'cat-2'),
    );
    await tester.pumpAndSettle();

    // Кнопка и цветной чип оба показывают название категории.
    expect(find.text('Учёба'), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('выбор категории в пикере вызывает onChanged', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );

    String? selected;
    await tester.pumpWidget(
      buildSubject(repository: repository, onChanged: (v) => selected = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();

    expect(selected, 'cat-1');
  });

  testWidgets('кнопка «крестик» сбрасывает выбор', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );

    String? selected = 'cat-1';
    await tester.pumpWidget(
      buildSubject(
        repository: repository,
        selectedCategoryId: 'cat-1',
        onChanged: (v) => selected = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('при enabled=false поле неактивно', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );

    String? selected = 'cat-1';
    await tester.pumpWidget(
      buildSubject(
        repository: repository,
        enabled: false,
        onChanged: (v) => selected = v,
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(button.onPressed, isNull);

    // При disabled «крестик» тоже неактивен.
    await tester.pumpWidget(
      buildSubject(
        repository: repository,
        enabled: false,
        selectedCategoryId: 'cat-1',
        onChanged: (v) => selected = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pump();

    expect(selected, 'cat-1');
  });

  testWidgets('ошибка загрузки показывает SnackBar', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => throw Exception('boom'),
    );

    await tester.pumpWidget(buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить категории.'), findsOneWidget);
  });

  testWidgets('смена householdId перезагружает список', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );
    when(() => repository.getForHousehold('household-2')).thenAnswer(
      (_) async => const [
        TaskCategory(
          id: 'cat-9',
          householdId: 'household-2',
          name: 'Работа',
          colorHex: '43A047',
        ),
      ],
    );

    await tester.pumpWidget(
      buildSubject(repository: repository, householdId: 'household-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Категория — необязательно'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(repository: repository, householdId: 'household-2'),
    );
    await tester.pumpAndSettle();

    verify(() => repository.getForHousehold('household-2')).called(1);
  });

  testWidgets('создание новой категории в пикере обновляет локальный список', (
    tester,
  ) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.getForHousehold('household-1')).thenAnswer(
      (_) async => categories,
    );
    when(() => repository.create(any())).thenAnswer(
      (_) async => const TaskCategory(
        id: 'cat-3',
        householdId: 'household-1',
        name: 'Работа',
        colorHex: '43A047',
      ),
    );

    String? selected;
    await tester.pumpWidget(
      buildSubject(repository: repository, onChanged: (v) => selected = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать новую'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Работа');
    await tester.pump();

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    // onChanged получил id новой категории.
    expect(selected, 'cat-3');

    // Повторное открытие пикера показывает новую категорию в списке.
    await tester.tap(find.text('Категория — необязательно'));
    await tester.pumpAndSettle();

    expect(find.text('Работа'), findsOneWidget);
  });
}

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}
