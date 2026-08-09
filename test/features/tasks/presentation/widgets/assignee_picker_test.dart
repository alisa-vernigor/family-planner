import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/presentation/widgets/assignee_picker.dart';

void main() {
  final members = [
    const HouseholdMember(
      profileId: 'user-1',
      displayName: 'Анна',
      role: 'member',
    ),
    const HouseholdMember(
      profileId: 'user-2',
      displayName: 'Влад',
      avatarUrl: 'https://example.com/ava.png',
      role: 'owner',
    ),
  ];

  Widget buildSubject({
    required ValueChanged<String?> onResult,
    List<HouseholdMember>? list,
    String? currentAssigneeId,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showAssigneePicker(
                  context: context,
                  members: list ?? members,
                  currentAssigneeId: currentAssigneeId,
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('показывает заголовок и список участников', (tester) async {
    await tester.pumpWidget(buildSubject(onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Назначить ответственного'), findsOneWidget);
    expect(find.text('Без ответственного'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Влад'), findsOneWidget);
  });

  testWidgets('выбор участника возвращает его profileId', (tester) async {
    String? result;
    await tester.pumpWidget(buildSubject(onResult: (r) => result = r));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    expect(result, 'user-1');
  });

  testWidgets('«Без ответственного» возвращает пустую строку', (tester) async {
    String? result;
    await tester.pumpWidget(buildSubject(onResult: (r) => result = r));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Без ответственного'));
    await tester.pumpAndSettle();

    expect(result, '');
  });

  testWidgets('текущий исполнитель отмечен галочкой', (tester) async {
    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, currentAssigneeId: 'user-1'),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('без участников показывает пустое состояние', (tester) async {
    await tester.pumpWidget(
      buildSubject(onResult: (_) {}, list: const []),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Нет участников для назначения'), findsOneWidget);
  });

  testWidgets('свайп вниз (закрытие) возвращает null', (tester) async {
    String? result = 'sentinel';
    await tester.pumpWidget(buildSubject(onResult: (r) => result = r));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Закрываем sheet через Navigator.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
