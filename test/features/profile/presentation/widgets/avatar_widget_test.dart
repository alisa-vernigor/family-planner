import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';

void main() {
  group('AvatarWidget (default constructor)', () {
    testWidgets('показывает первую букву, когда нет avatarUrl', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('показывает "?" когда displayName пустой', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: '',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('показывает "JD" для "John Doe"', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'John Doe',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('показывает одну букву для однословного имени', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Mona',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets(
        'показывает NetworkImage когда avatarUrl установлен', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      final circleAvatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar).first,
      );

      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
    });

    testWidgets('onTap вызывается при нажатии', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        timezone: 'Europe/Moscow',
      );

      var wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              profile: profile,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('onTap null-safe — нет InkWell при onTap = null',
        (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(home: AvatarWidget(profile: profile)),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('radius влияет на размер CircleAvatar', (tester) async {
      const profile = UserProfile(
        id: '1',
        displayName: 'Alice',
        timezone: 'Europe/Moscow',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget(profile: profile, radius: 30),
        ),
      );

      final circleAvatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar),
      );

      expect(circleAvatar.radius, 30);
    });
  });

  group('AvatarWidget.fromMember', () {
    testWidgets('показывает инициалы по имени участника', (tester) async {
      const member = HouseholdMember(
        profileId: '1',
        displayName: 'Bob',
        role: 'member',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget.fromMember(member: member),
        ),
      );

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('показывает NetworkImage когда у участника есть avatarUrl',
        (tester) async {
      const member = HouseholdMember(
        profileId: '1',
        displayName: 'Bob',
        avatarUrl: 'https://example.com/bob.png',
        role: 'member',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget.fromMember(member: member),
        ),
      );

      final circleAvatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar).first,
      );

      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
    });
  });

  group('AvatarWidget.url', () {
    testWidgets('показывает инициалы когда imageUrl равен null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget.url(
            imageUrl: null,
            displayName: 'Charlie',
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('показывает инициалы когда imageUrl пустая строка',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget.url(
            imageUrl: '',
            displayName: 'Diana',
          ),
        ),
      );

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('показывает NetworkImage когда imageUrl установлен',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AvatarWidget.url(
            imageUrl: 'https://example.com/charlie.png',
            displayName: 'Charlie',
          ),
        ),
      );

      final circleAvatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar).first,
      );

      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
    });
  });
}
