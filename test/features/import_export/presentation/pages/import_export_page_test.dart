import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/presentation/pages/import_export_page.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

const filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;

  setUpAll(() {
    registerFallbackValue(
      CreateTaskParams(
        householdId: 'household-1',
        title: 'fallback',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime(2026, 8, 9),
      ),
    );
  });

  setUp(() {
    mocks = MockRepositoryFactory();
    categoryRepo = MockTaskCategoryRepository();
    subtaskRepo = MockTaskSubtaskRepository();
    when(() => mocks.connectivity.currentOnline).thenReturn(true);
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(filePickerChannel, null);
  });

  const householdId = 'household-1';
  const member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Мама',
    role: 'owner',
  );

  Task buildTask({String id = 'task-1', String title = 'Помыть посуду'}) {
    return Task(
      id: id,
      householdId: householdId,
      title: title,
      estimatedDurationMinutes: 30,
      plannedFor: DateTime(2026, 8, 9),
      allowedMemberIds: const [],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 8, 1),
    );
  }

  void stubCommon({bool online = true}) {
    when(() => mocks.connectivity.currentOnline).thenReturn(online);
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const [member]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);
  }

  /// Мокает системный буфер обмена: [text] == null → пустой буфер.
  void mockClipboard(String? text) {
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return text == null ? null : <String, dynamic>{'text': text};
      }
      return null;
    });
  }

  Widget buildSubject({VoidCallback? onImported}) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>(create: (_) => mocks.task),
        RepositoryProvider<HouseholdRepository>(
          create: (_) => mocks.household,
        ),
        RepositoryProvider<TaskCategoryRepository>(
          create: (_) => categoryRepo,
        ),
        RepositoryProvider<TaskSubtaskRepository>(
          create: (_) => subtaskRepo,
        ),
        RepositoryProvider<ConnectivityService>(
          create: (_) => mocks.connectivity,
        ),
      ],
      child: MaterialApp(
        home: ImportExportPage(
          householdId: householdId,
          onImported: onImported,
        ),
      ),
    );
  }

  /// Дожимает auto-dismiss таймер SnackBar, чтобы не осталось висящих Timer'ов.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('показывает заголовок, секции и все действия', (tester) async {
    stubCommon();

    await tester.pumpWidget(buildSubject());

    expect(find.text('Импорт / экспорт задач'), findsOneWidget);
    expect(find.text('Импорт'), findsOneWidget);
    expect(find.text('Экспорт'), findsOneWidget);
    expect(find.text('Импортировать из буфера'), findsOneWidget);
    expect(find.text('Импортировать из файла'), findsOneWidget);
    expect(find.text('Экспортировать в буфер'), findsOneWidget);
    expect(find.text('Экспортировать в файл'), findsOneWidget);
  });

  testWidgets('показывает спиннер во время операции', (tester) async {
    stubCommon();
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    // Буфер «зависает» — операция не завершается, спиннер виден.
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return Completer<Map<String, dynamic>>().future;
      }
      return null;
    });

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('импорт из пустого буфера показывает snack', (tester) async {
    stubCommon();
    mockClipboard(null);

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(find.text('В буфере обмена нет текста.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('импорт валидного JSON создаёт задачу и вызывает onImported', (
    tester,
  ) async {
    stubCommon();
    mockClipboard(
      '{"version":1,"tasks":[{"title":"Помыть посуду","duration_minutes":30}]}',
    );
    when(() => mocks.task.create(params: any(named: 'params')))
        .thenAnswer((_) async => buildTask());
    var imported = false;

    await tester.pumpWidget(buildSubject(onImported: () => imported = true));
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    expect(find.text('Импортировано: 1'), findsOneWidget);
    expect(imported, isTrue);
    await drainSnackBar(tester);
  });

  testWidgets('некорректный JSON показывает snack об ошибке', (tester) async {
    stubCommon();
    mockClipboard('не-json');

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Не удалось разобрать JSON'),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });

  testWidgets('импорт офлайн показывает snack', (tester) async {
    stubCommon(online: false);
    mockClipboard(
      '{"version":1,"tasks":[{"title":"t","duration_minutes":30}]}',
    );

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Импорт задач работает только при подключении к интернету',
      ),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });

  testWidgets('отмена выбора файла показывает snack', (tester) async {
    stubCommon();
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      filePickerChannel,
      (call) async => null,
    );

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из файла'));
    await tester.pumpAndSettle();

    expect(find.text('Файл пуст или выбор отменён.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('экспорт в буфер копирует JSON и показывает snack', (
    tester,
  ) async {
    stubCommon();
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [buildTask()]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
    String? written;
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        written = (call.arguments as Map)['text'] as String?;
        return null;
      }
      return null;
    });

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Экспортировать в буфер'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).called(1);
    expect(written, isNotNull);
    expect(written, contains('Помыть посуду'));
    expect(find.text('JSON скопирован в буфер обмена.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('экспорт в файл без пикера показывает snack', (tester) async {
    stubCommon();
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [buildTask()]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Экспортировать в файл'));
    await tester.pumpAndSettle();

    expect(find.text('Сохранение отменено или не удалось.'), findsOneWidget);
    await drainSnackBar(tester);
  });
}
