import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/presentation/widgets/start_time_field.dart';

void main() {
  Widget buildSubject({
    Duration? value,
    ValueChanged<Duration?>? onChanged,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StartTimeField(
          value: value,
          onChanged: onChanged ?? (_) {},
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets('показывает «Время начала (весь день)», если время не задано', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Время начала (весь день)'), findsOneWidget);
    expect(find.text('Убрать время'), findsNothing);
  });

  testWidgets('показывает выбранное время', (tester) async {
    await tester.pumpWidget(
      buildSubject(value: const Duration(hours: 9, minutes: 30)),
    );

    expect(find.text('Начало: 09:30'), findsOneWidget);
    expect(find.text('Убрать время'), findsOneWidget);
  });

  testWidgets('выбор времени через time picker вызывает onChanged', (
    tester,
  ) async {
    Duration? result;
    await tester.pumpWidget(
      buildSubject(onChanged: (time) => result = time),
    );

    await tester.tap(find.text('Время начала (весь день)'));
    await tester.pumpAndSettle();

    // TimePicker открыт (по умолчанию 09:00). Подтверждаем выбор.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, const Duration(hours: 9, minutes: 0));
  });

  testWidgets('time picker при заданном времени стартует с него и подтверждает', (
    tester,
  ) async {
    Duration? result;
    await tester.pumpWidget(
      buildSubject(
        value: const Duration(hours: 14, minutes: 30),
        onChanged: (time) => result = time,
      ),
    );

    await tester.tap(find.text('Начало: 14:30'));
    await tester.pumpAndSettle();

    // TimePicker открыт (initial 14:30). Подтверждаем выбор.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, const Duration(hours: 14, minutes: 30));
  });

  testWidgets('кнопка «Убрать время» очищает значение', (tester) async {
    Duration? result = const Duration(hours: 9);
    await tester.pumpWidget(
      buildSubject(
        value: result,
        onChanged: (time) => result = time,
      ),
    );

    await tester.tap(find.text('Убрать время'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('при disabled поле не кликабельно', (tester) async {
    Duration? result = const Duration(hours: 9);
    await tester.pumpWidget(
      buildSubject(
        value: result,
        enabled: false,
        onChanged: (time) => result = time,
      ),
    );

    await tester.tap(find.text('Убрать время'));
    await tester.pumpAndSettle();

    // disabled → onChanged не вызван, значение сохранилось.
    expect(result, const Duration(hours: 9));
  });
}
