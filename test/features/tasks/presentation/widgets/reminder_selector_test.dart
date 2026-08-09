import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/presentation/widgets/reminder_selector.dart';

void main() {
  Widget buildSubject({
    int? value,
    ValueChanged<int?>? onChanged,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ReminderSelector(
          value: value,
          onChanged: onChanged ?? (_) {},
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets('null показывает «Без напоминания»', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Без напоминания'), findsOneWidget);
  });

  testWidgets('выбор «За 5 мин» вызывает onChanged(5)', (tester) async {
    int? result;
    await tester.pumpWidget(buildSubject(onChanged: (v) => result = v));

    await tester.tap(find.text('Без напоминания'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('За 5 мин').last);
    await tester.pumpAndSettle();

    expect(result, 5);
  });

  testWidgets('выбор «За день» вызывает onChanged(1440)', (tester) async {
    int? result;
    await tester.pumpWidget(buildSubject(onChanged: (v) => result = v));

    await tester.tap(find.text('Без напоминания'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('За день').last);
    await tester.pumpAndSettle();

    expect(result, 1440);
  });

  testWidgets('выбор «За 1 час» вызывает onChanged(60)', (tester) async {
    int? result;
    await tester.pumpWidget(buildSubject(onChanged: (v) => result = v));

    await tester.tap(find.text('Без напоминания'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('За 1 час').last);
    await tester.pumpAndSettle();

    expect(result, 60);
  });

  testWidgets('выбранное значение отображается', (tester) async {
    await tester.pumpWidget(buildSubject(value: 15));

    expect(find.text('За 15 мин'), findsOneWidget);
  });

  testWidgets('при enabled=false dropdown неактивен', (tester) async {
    await tester.pumpWidget(buildSubject(value: 5, enabled: false));

    final dropdown = tester.widget<DropdownButtonFormField<int?>>(
      find.byKey(const Key('reminder_selector')),
    );
    expect(dropdown.onChanged, isNull);
  });
}
