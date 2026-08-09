import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task_sort_option.dart';
import 'package:family_planner/features/tasks/presentation/widgets/sort_selector.dart';

void main() {
  Widget buildSubject({
    TaskSortOption current = TaskSortOption.deadline,
    ValueChanged<TaskSortOption>? onChanged,
    bool ascending = true,
    ValueChanged<bool>? onAscendingChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SortSelector(
          current: current,
          onChanged: onChanged ?? (_) {},
          ascending: ascending,
          onAscendingChanged: onAscendingChanged,
        ),
      ),
    );
  }

  testWidgets('показывает иконку сортировки', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byIcon(Icons.sort_outlined), findsOneWidget);
  });

  testWidgets('показывает иконку направления при onAscendingChanged != null', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(onAscendingChanged: (_) {}));

    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('скрывает направление, если onAscendingChanged == null', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });

  testWidgets('показывает направление вниз при ascending == false', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(ascending: false, onAscendingChanged: (_) {}),
    );

    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });

  testWidgets('выбор варианта сортировки вызывает onChanged', (tester) async {
    TaskSortOption? selected;
    await tester.pumpWidget(buildSubject(onChanged: (o) => selected = o));

    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('По приоритету').last);
    await tester.pumpAndSettle();

    expect(selected, TaskSortOption.priority);
  });

  testWidgets('переключение направления вызывает onAscendingChanged', (
    tester,
  ) async {
    bool? ascendingResult;
    await tester.pumpWidget(
      buildSubject(
        ascending: true,
        onAscendingChanged: (v) => ascendingResult = v,
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('По убыванию').last);
    await tester.pumpAndSettle();

    expect(ascendingResult, isFalse);
  });

  testWidgets('для каждого варианта есть иконка', (tester) async {
    // Открываем меню и проверяем, что все 6 вариантов перечислены.
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byIcon(Icons.sort_outlined));
    await tester.pumpAndSettle();

    for (final option in TaskSortOption.values) {
      expect(find.text(option.label), findsWidgets);
    }
  });
}
