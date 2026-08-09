import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/presentation/widgets/category_chip.dart';

void main() {
  testWidgets('null category → не рендерится (SizedBox.shrink)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryChip(category: null)),
      ),
    );

    expect(find.byType(CategoryChip), findsOneWidget);
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('показывает название категории на цветном фоне', (tester) async {
    const category = TaskCategory(
      id: 'cat-1',
      householdId: 'h-1',
      name: 'Дом',
      colorHex: '43A047',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryChip(category: category)),
      ),
    );

    expect(find.text('Дом'), findsOneWidget);
    // Точка-цвет и текст.
    expect(find.byType(Container), findsNWidgets(2));
  });

  testWidgets('категория с null colorHex использует цвет по умолчанию', (
    tester,
  ) async {
    const category = TaskCategory(
      id: 'cat-2',
      householdId: 'h-1',
      name: 'Без цвета',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryChip(category: category)),
      ),
    );

    expect(find.text('Без цвета'), findsOneWidget);
  });
}
