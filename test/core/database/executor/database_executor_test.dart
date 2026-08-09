import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/executor/database_executor_io.dart'
    as io;
import 'package:family_planner/core/database/executor/database_executor_web.dart'
    as web;

/// Тестовая реализация PathProviderPlatform, возвращающая temp-директорию.
final class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late PathProviderPlatform original;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fp_executor_test');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tmp.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = original;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('database executors', () {
    test('io: tryCreateDatabaseExecutor возвращает не-null LazyDatabase', () {
      final executor = io.tryCreateDatabaseExecutor();
      expect(executor, isNotNull);
      // LazyDatabase откладывает открытие до первого запроса,
      // поэтому конструкция не требует platform channels / I/O.
      expect(executor.toString(), contains('LazyDatabase'));
    });

    test('io: appDatabaseFile резолвит путь под documents-директорией', () async {
      final file = await io.appDatabaseFile();
      expect(file.path, '${tmp.path}/family_planner.db');
    });

    test('io: LazyDatabase открывает файл при обращении к БД', () async {
      final executor = io.tryCreateDatabaseExecutor()!;
      final database = AppDatabase(executor);
      await database.customStatement('SELECT 1');

      final dbFile = File('${tmp.path}/family_planner.db');
      expect(dbFile.existsSync(), isTrue);
      await database.close();
    });

    test('web: tryCreateDatabaseExecutor возвращает null (онлайн-режим)', () {
      expect(web.tryCreateDatabaseExecutor(), isNull);
    });
  });
}
