import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/auth/presentation/widgets/sign_out_button.dart';

void main() {
  testWidgets('показывает кнопку выхода', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [SignOutButton(onPressed: () {})]),
        ),
      ),
    );

    expect(find.byTooltip('Выйти'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
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

    await tester.tap(find.byTooltip('Выйти'));
    await tester.pump();

    expect(wasPressed, isTrue);
  });
}
