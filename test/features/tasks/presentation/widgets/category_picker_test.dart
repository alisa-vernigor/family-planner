import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/presentation/widgets/category_picker.dart';

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
    required ValueChanged<Object?> onResult,
    List<TaskCategory>? list,
    String? selectedCategoryId,
    MockTaskCategoryRepository? repository,
  }) {
    return MockRepositoryFactoryProvider(
      repository: repository,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showCategoryPicker(
                    context: context,
                    householdId: 'household-1',
                    categories: list ?? categories,
                    selectedCategoryId: selectedCategoryId,
                  );
                  onResult(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('показывает заголовок и список категорий', (tester) async {
    await tester.pumpWidget(buildSubject(onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Категория'), findsOneWidget);
    expect(find.text('Без категории'), findsOneWidget);
    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('Учёба'), findsOneWidget);
    expect(find.text('Создать новую'), findsOneWidget);
  });

  testWidgets('выбор «Без категории» возвращает null', (tester) async {
    Object? result = 'sentinel';
    await tester.pumpWidget(buildSubject(onResult: (r) => result = r));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Без категории'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('выбор категории возвращает TaskCategory', (tester) async {
    Object? result;
    await tester.pumpWidget(buildSubject(onResult: (r) => result = r));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();

    expect(result, isA<TaskCategory>());
    expect((result as TaskCategory).id, 'cat-1');
  });

  testWidgets('выбранная категория отмечена галочкой', (tester) async {
    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, selectedCategoryId: 'cat-2'),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('пустой список категорий показывает только «Без категории»', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, list: const []),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Покупки'), findsNothing);
    expect(find.text('Без категории'), findsOneWidget);
    expect(find.text('Создать новую'), findsOneWidget);
  });

  testWidgets('создание новой категории вызывает repository.create', (
    tester,
  ) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.create(any())).thenAnswer(
      (_) async => const TaskCategory(
        id: 'cat-3',
        householdId: 'household-1',
        name: 'Работа',
        colorHex: '43A047',
      ),
    );

    Object? result;
    await tester.pumpWidget(
      buildSubject(onResult: (r) => result = r, repository: repository),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать новую'));
    await tester.pumpAndSettle();

    expect(find.text('Новая категория'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Работа');
    await tester.pump();

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    verify(() => repository.create(
      any<CreateTaskCategoryParams>(),
    )).called(1);
    expect(result, isA<TaskCategory>());
    expect((result as TaskCategory).name, 'Работа');
  });

  testWidgets('создание категории без названия показывает ошибку', (
    tester,
  ) async {
    final repository = MockTaskCategoryRepository();

    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, repository: repository),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать новую'));
    await tester.pumpAndSettle();

    // Оставляем название пустым и жмём «Создать».
    await tester.tap(find.text('Создать'));
    await tester.pump();

    expect(find.text('Введите название категории.'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('ошибка создания категории показывает SnackBar', (tester) async {
    final repository = MockTaskCategoryRepository();
    when(() => repository.create(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, repository: repository),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать новую'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Работа');
    await tester.pump();

    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось создать категорию.'), findsOneWidget);
  });
}

/// Оборачивает в RepositoryProvider&lt;TaskCategoryRepository&gt;.
final class MockRepositoryFactoryProvider extends StatelessWidget {
  const MockRepositoryFactoryProvider({
    required this.child,
    this.repository,
    super.key,
  });

  final Widget child;
  final MockTaskCategoryRepository? repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TaskCategoryRepository>(
      create: (_) => repository ?? MockTaskCategoryRepository(),
      child: child,
    );
  }
}

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}
