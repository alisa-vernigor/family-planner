import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:family_planner/core/logging/app_logger.dart';

/// Работа с файлами/буфером обмена для импорта/экспорта JSON.
///
/// - Импорт: вставка из буфера (все платформы) или выбор `.json`-файла
///   через [FilePicker] (mobile/desktop).
/// - Экспорт: копирование в буфер (все платформы) или сохранение файла
///   через [FilePicker] (mobile/desktop; на web кнопка сохранения скрыта).
final class TaskFileService {
  /// Читает JSON-строку из системного буфера обмена.
  static Future<String?> readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      AppLogger.warning('Не удалось прочитать буфер обмена: $e');
      return null;
    }
  }

  /// Копирует [text] в системный буфер обмена.
  static Future<bool> writeClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e) {
      AppLogger.warning('Не удалось записать в буфер обмена: $e');
      return false;
    }
  }

  /// Показывает пикер выбора `.json`-файла и возвращает его содержимое.
  ///
  /// Возвращает `null`, если пользователь отменил выбор.
  static Future<String?> pickJsonFile() async {
    if (kIsWeb) return null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      if (file.path != null && file.bytes == null) {
        return File(file.path!).readAsString();
      }
      if (file.bytes != null) {
        return String.fromCharCodes(file.bytes!);
      }
      return null;
    } catch (e) {
      AppLogger.warning('Не удалось выбрать файл: $e');
      rethrow;
    }
  }

  /// Показывает диалог сохранения и пишет [content] в `.json`-файл.
  ///
  /// Возвращает `true`, если файл сохранён. На web не поддерживается
  /// (возвращает `false`).
  static Future<bool> saveJsonFile(
    String content, {
    String suggestedName = 'tasks.json',
  }) async {
    if (kIsWeb) return false;

    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Сохранить задачи',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return false;

      await File(path).writeAsString(content);
      AppLogger.info('Задачи сохранены в файл: $path');
      return true;
    } catch (e) {
      AppLogger.warning('Не удалось сохранить файл: $e');
      return false;
    }
  }
}
