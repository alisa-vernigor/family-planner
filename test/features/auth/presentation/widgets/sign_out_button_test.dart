import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/auth/presentation/widgets/sign_out_button.dart';

void main() {
  group('SignOutButton', () {
    const tooltip = 'Выйти';

    testWidgets('отображает иконку выхода с тултипом', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [SignOutButton(onPressed: () {})]),
          ),
        ),
      );

      expect(find.byTooltip(tooltip), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('использует виджет IconButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignOutButton(onPressed: () {}),
          ),
        ),
      );

      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('вызывает onPressed после нажатия', (tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignOutButton(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();

      expect(wasPressed, isTrue);
    });
  });
}
