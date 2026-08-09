import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/data/task_file_service.dart';
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

/// Тестовый `FilePickerPlatform` — подменяет статические `FilePicker.*`.
final class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform({
    this.result,
    this.savePath,
  });

  final FilePickerResult? result;
  final String? savePath;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return result;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    return savePath;
  }
}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskCategoryRepository categoryRepo;
  late MockTaskSubtaskRepository subtaskRepo;
  late FilePickerPlatform originalPicker;

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
    originalPicker = FilePickerPlatform.instance;
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(filePickerChannel, null);
    FilePickerPlatform.instance = originalPicker;
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

  testWidgets('экспорт в файл при ошибке пикера показывает snack', (
    tester,
  ) async {
    stubCommon();
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [buildTask()]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(filePickerChannel, (call) async {
      if (call.method == 'save') throw PlatformException(code: 'e');
      return null;
    });

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Экспортировать в файл'));
    await tester.pumpAndSettle();

    expect(find.text('Сохранение отменено или не удалось.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('импорт из файла: пустое содержимое → snack', (tester) async {
    stubCommon();
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      result: FilePickerResult([
        PlatformFile(name: 'tasks.json', size: 0),
      ]),
    );

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из файла'));
    await tester.pumpAndSettle();

    expect(find.text('Файл пуст или выбор отменён.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('импорт из файла: валидный JSON создаёт задачу', (tester) async {
    stubCommon();
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      result: FilePickerResult([
        PlatformFile(
          name: 'tasks.json',
          size: 14,
          bytes: Uint8List.fromList(
            utf8.encode('{"version":1,"tasks":[{"title":"Из файла"}]}'),
          ),
        ),
      ]),
    );
    when(() => mocks.task.create(params: any(named: 'params')))
        .thenAnswer((_) async => buildTask(title: 'Из файла'));

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из файла'));
    await tester.pumpAndSettle();

    verify(() => mocks.task.create(params: any(named: 'params'))).called(1);
    expect(find.text('Импортировано: 1'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('непредвиденная ошибка импорта показывает общий snack', (
    tester,
  ) async {
    stubCommon();
    mockClipboard('{"version":1,"tasks":[{"title":"t","duration_minutes":30}]}');
    // getMembers бросает — use case падает, ловится общим catch.
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось импортировать задачи.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('файл без задач показывает «В файле нет задач»', (tester) async {
    stubCommon();
    mockClipboard('{"version":1,"tasks":[]}');

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(find.text('В файле нет задач.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('импорт с ошибками задач показывает превью и счётчик', (
    tester,
  ) async {
    stubCommon();
    mockClipboard('''
    {
      "version": 1,
      "tasks": [
        {"title": "   "},
        {"title": "   "},
        {"title": "   "},
        {"title": "   "},
        {"title": "Хорошая"}
      ]
    }
    ''');
    when(() => mocks.task.create(params: any(named: 'params')))
        .thenAnswer((_) async => buildTask(title: 'Хорошая'));

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Импортировать из буфера'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Импортировано: 1'), findsOneWidget);
    expect(find.textContaining('пропущено: 4'), findsOneWidget);
    expect(find.textContaining('и ещё 1'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('сбой копирования в буфер показывает snack', (tester) async {
    stubCommon();
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [buildTask()]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'e');
      }
      return null;
    });

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Экспортировать в буфер'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось скопировать в буфер.'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('экспорт в файл успешно сохраняет JSON', (tester) async {
    stubCommon();
    // saveJsonFile пишет реальным dart:io (не завершается в FakeAsync-зоне
    // testWidgets) — подменяем writer на in-memory запись.
    final original = TaskFileService.writeJsonFile;
    addTearDown(() => TaskFileService.writeJsonFile = original);
    String? written;
    TaskFileService.writeJsonFile = (path, content) async {
      written = content;
    };
    FilePickerPlatform.instance = _FakeFilePickerPlatform(savePath: '/tmp/tasks.json');
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [buildTask()]);
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('Экспортировать в файл'));
    await tester.pumpAndSettle();

    expect(find.text('Задачи сохранены в файл.'), findsOneWidget);
    expect(written, isNotNull);
    expect(written, contains('Помыть посуду'));
    await drainSnackBar(tester);
  });
}
