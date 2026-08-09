import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/presentation/widgets/priority_selector.dart';

void main() {
  Widget buildSubject({
    EisenhowerPriority? value,
    ValueChanged<EisenhowerPriority?>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PrioritySelector(
          value: value,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('показывает заголовок и все 4 приоритета', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Приоритет'), findsOneWidget);
    for (final p in EisenhowerPriority.values) {
      expect(find.text(p.label), findsOneWidget);
    }
    // Без выбранного значения кнопка «Сбросить» не показывается.
    expect(find.text('Сбросить'), findsNothing);
  });

  testWidgets('выбор приоритета вызывает onChanged', (tester) async {
    EisenhowerPriority? result;
    await tester.pumpWidget(buildSubject(onChanged: (v) => result = v));

    await tester.tap(find.text(EisenhowerPriority.urgentImportant.label));
    await tester.pumpAndSettle();

    expect(result, EisenhowerPriority.urgentImportant);
  });

  testWidgets('повторный тап по выбранному сбрасывает в null', (tester) async {
    EisenhowerPriority? result = EisenhowerPriority.urgentImportant;
    await tester.pumpWidget(
      buildSubject(
        value: EisenhowerPriority.urgentImportant,
        onChanged: (v) => result = v,
      ),
    );

    // Выбранное значение показывает «Сбросить».
    expect(find.text('Сбросить'), findsOneWidget);

    await tester.tap(find.text(EisenhowerPriority.urgentImportant.label));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('кнопка «Сбросить» вызывает onChanged(null)', (tester) async {
    EisenhowerPriority? result = EisenhowerPriority.notUrgentImportant;
    await tester.pumpWidget(
      buildSubject(
        value: EisenhowerPriority.notUrgentImportant,
        onChanged: (v) => result = v,
      ),
    );

    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('выбранный приоритет отображается с меткой', (tester) async {
    await tester.pumpWidget(
      buildSubject(value: EisenhowerPriority.urgentNotImportant),
    );

    // Все метки приоритетов по-прежнему видны.
    expect(find.text('Срочно, но не важно'), findsOneWidget);
    expect(find.text('Сбросить'), findsOneWidget);
  });
}
