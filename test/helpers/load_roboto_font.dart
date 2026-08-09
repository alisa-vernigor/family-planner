import 'dart:io';

import 'package:flutter/services.dart';

/// Загружает настоящий Roboto-шрифт из кэша Flutter SDK.
///
/// В widget-тестах по умолчанию используется Ahem-шрифт, в котором
/// кириллические глифы слишком широкие — из-за этого переполняются
/// компактные Row-виджеты (например, пункты PopupMenuButton).
///
/// Путь к кэшу зависит от окружения, поэтому при отсутствии файла
/// функция просто ничего не делает (тест продолжит работать на Ahem).
Future<void> loadRobotoFont() async {
  final home = Platform.environment['HOME'] ?? '';
  final candidates = [
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    '$home/development/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final data = await file.readAsBytes();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.view(data.buffer)));
      await loader.load();
      return;
    } catch (_) {
      // Продолжаем со следующей кандидатурой.
    }
  }
}
