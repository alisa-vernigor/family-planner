import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/import_export/data/task_file_service.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
  });

  tearDown(() {
    // Восстанавливаем платформенную реализацию FilePicker после фейков.
    FilePickerPlatform.instance = originalPicker;
  });

  group('TaskFileService.readClipboard', () {
    test('возвращает текст из буфера', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '{"hello":1}'};
        }
        return null;
      });

      final result = await TaskFileService.readClipboard();

      expect(result, '{"hello":1}');
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('возвращает null при пустом буфере', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return null;
        return null;
      });

      final result = await TaskFileService.readClipboard();

      expect(result, isNull);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('возвращает null при ошибке платформы', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        throw PlatformException(code: 'e', message: 'no clipboard');
      });

      final result = await TaskFileService.readClipboard();

      expect(result, isNull);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('TaskFileService.writeClipboard', () {
    test('возвращает true при успешной записи', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        return null;
      });

      final ok = await TaskFileService.writeClipboard('hello');

      expect(ok, isTrue);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('возвращает false при ошибке', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        throw PlatformException(code: 'e');
      });

      final ok = await TaskFileService.writeClipboard('hello');

      expect(ok, isFalse);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('TaskFileService.pickJsonFile', () {
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('когда FilePicker недоступен — пробрасывает ошибку', () async {
      // FilePicker работает через MethodChannel; без мока в тестах его нет →
      // MissingPluginException → catch → rethrow.
      await expectLater(
        TaskFileService.pickJsonFile(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('пикер вернул файл с path — читает содержимое', () async {
      final dir = await Directory.systemTemp.createTemp('fp_test');
      final file = File('${dir.path}/tasks.json');
      await file.writeAsString('{"from":"file"}');

      messenger.setMockMethodCallHandler(channel, (call) async {
        // MethodChannelFilePicker вызывает invokeListMethod('custom', ...).
        if (call.method == 'custom') {
          return [
            {
              'path': file.path,
              'identifier': 'id1',
              'name': 'tasks.json',
              'size': 0,
            },
          ];
        }
        return null;
      });

      final result = await TaskFileService.pickJsonFile();
      expect(result, '{"from":"file"}');
    });

    test('пикер вернул null (отмена) — возвращает null', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'custom') return null;
        return null;
      });

      final result = await TaskFileService.pickJsonFile();
      expect(result, isNull);
    });

    test('пикер вернул файл с bytes (web/mobile) — читает из bytes', () async {
      FilePickerPlatform.instance = _FakeFilePickerPlatform(
        result: FilePickerResult([
          PlatformFile(
            name: 'tasks.json',
            size: 14,
            bytes: Uint8List.fromList(utf8.encode('{"from":"bytes"}')),
          ),
        ]),
      );

      final result = await TaskFileService.pickJsonFile();
      expect(result, '{"from":"bytes"}');
    });
  });

  group('TaskFileService.saveJsonFile', () {
    test('когда FilePicker недоступен — возвращает false', () async {
      // method-channel файл-пикер бросает ArgumentError до вызова канала,
      // т.к. saveFile требует bytes на mobile; catch в saveJsonFile
      // превращает это в false.
      final ok = await TaskFileService.saveJsonFile('{"a":1}');
      expect(ok, isFalse);
    });

    test('успешное сохранение файла — возвращает true и пишет содержимое',
        () async {
      final dir = await Directory.systemTemp.createTemp('fp_save_test');
      final savePath = '${dir.path}/tasks.json';

      FilePickerPlatform.instance = _FakeFilePickerPlatform(savePath: savePath);

      final ok = await TaskFileService.saveJsonFile('{"a":1}');

      expect(ok, isTrue);
      final file = File(savePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '{"a":1}');
    });

    test('замена writeJsonFile перехватывает запись (для виджет-тестов)',
        () async {
      // Сохраняем оригинал, чтобы не сломать другие тесты.
      final original = TaskFileService.writeJsonFile;
      addTearDown(() => TaskFileService.writeJsonFile = original);

      String? writtenPath;
      String? writtenContent;
      TaskFileService.writeJsonFile = (path, content) async {
        writtenPath = path;
        writtenContent = content;
      };

      FilePickerPlatform.instance =
          _FakeFilePickerPlatform(savePath: '/tmp/fake_tasks.json');

      final ok = await TaskFileService.saveJsonFile('{"x":1}');

      expect(ok, isTrue);
      expect(writtenPath, '/tmp/fake_tasks.json');
      expect(writtenContent, '{"x":1}');
    });
  });
}
