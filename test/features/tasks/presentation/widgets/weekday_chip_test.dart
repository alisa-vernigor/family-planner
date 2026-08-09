import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/presentation/widgets/weekday_chip.dart';

void main() {
  Widget buildSubject({
    int day = 1,
    String label = 'Пн',
    Set<int> selectedDays = const {},
    bool isEnabled = true,
    void Function(int, bool)? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WeekdayChip(
          day: day,
          label: label,
          selectedDays: selectedDays,
          isEnabled: isEnabled,
          onChanged: onChanged ?? (_, _) {},
        ),
      ),
    );
  }

  testWidgets('показывает label и не выбран', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Пн'), findsOneWidget);

    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('weekday_chip_1')),
    );
    expect(chip.selected, isFalse);
  });

  testWidgets('выбранный день подсвечивается', (tester) async {
    await tester.pumpWidget(
      buildSubject(day: 2, label: 'Вт', selectedDays: {2}),
    );

    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('weekday_chip_2')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('тап вызывает onChanged(day, true)', (tester) async {
    int? changedDay;
    bool? changedSelected;
    await tester.pumpWidget(
      buildSubject(
        onChanged: (day, selected) {
          changedDay = day;
          changedSelected = selected;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('weekday_chip_1')));
    await tester.pump();

    expect(changedDay, 1);
    expect(changedSelected, isTrue);
  });

  testWidgets('при isEnabled=false onSelected == null', (tester) async {
    await tester.pumpWidget(buildSubject(isEnabled: false));

    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('weekday_chip_1')),
    );
    expect(chip.onSelected, isNull);
  });
}
