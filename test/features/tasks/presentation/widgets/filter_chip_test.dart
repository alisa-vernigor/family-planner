import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/presentation/widgets/filter_chip.dart';

void main() {
  Widget buildFilter({
    String label = 'Все',
    bool selected = false,
    VoidCallback? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FilterChipWidget(
          label: label,
          selected: selected,
          onSelected: onSelected ?? () {},
        ),
      ),
    );
  }

  group('FilterChipWidget', () {
    testWidgets('показывает label', (tester) async {
      await tester.pumpWidget(buildFilter(label: 'Мои задачи'));

      expect(find.text('Мои задачи'), findsOneWidget);
    });

    testWidgets('вызывает onSelected по тапу', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(buildFilter(onSelected: () => tapped++));

      await tester.tap(find.byType(FilterChipWidget));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('не крашится при выбранном состоянии', (tester) async {
      await tester.pumpWidget(buildFilter(selected: true));

      expect(find.text('Все'), findsOneWidget);
    });
  });

  group('InfoChip', () {
    testWidgets('показывает иконку и label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoChip(
              icon: Icons.timer_outlined,
              label: '30 мин',
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('30 мин'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('применяет цвет к тексту', (tester) async {
      const color = Color(0xFFE53935);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoChip(
              icon: Icons.schedule_outlined,
              label: 'метка',
              color: color,
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('метка'));
      expect(text.style?.color, color);
    });
  });
}
