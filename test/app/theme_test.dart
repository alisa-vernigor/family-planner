import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/app/theme.dart';

void main() {
  group('AppTheme', () {
    test('приватный конструктор не вызывается напрямую', () {
      expect(AppTheme, isA<Type>());
    });

    test('light() возвращает Material 3 тему с seed-цветом', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, isNot(Colors.transparent));
    });

    test('dark() возвращает тёмную тему с seed-цветом', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(Colors.transparent));
    });

    test('кастомизированные темы компонентов сконфигурированы', () {
      final theme = AppTheme.light();

      // AppBar
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.centerTitle, isFalse);

      // Card — скруглённые углы и нулевой margin.
      final cardShape = theme.cardTheme.shape;
      expect(cardShape, isA<RoundedRectangleBorder>());
      expect(theme.cardTheme.margin, EdgeInsets.zero);

      // Input — filled.
      expect(theme.inputDecorationTheme.filled, isTrue);

      // NavigationBar — высота и alwaysShow.
      expect(theme.navigationBarTheme.height, 64);
      expect(
        theme.navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );

      // SnackBar — floating.
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);

      // FAB, Dialog, Chip, Divider, PopupMenu.
      expect(theme.floatingActionButtonTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.dividerTheme.thickness, 1);
      expect(theme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());

      // Кнопки.
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.outlinedButtonTheme.style, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
    });
  });
}
