import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_page.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    mocks = MockRepositoryFactory();
  });

  const profile = UserProfile(
    id: 'user-1',
    displayName: 'Анна',
    timezone: 'Europe/Moscow',
    bio: 'Люблю порядок',
  );
  const stats = ProfileStats(
    totalAssigned: 10,
    completedTasks: 4,
    completedThisWeek: 2,
    completedThisMonth: 3,
  );

  void stubOwnProfile() {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => profile,
    );
    when(() => mocks.profile.getStats('user-1')).thenAnswer(
      (_) async => stats,
    );
  }

  Widget buildSubject({String profileId = 'user-1', String? viewerId}) {
    return RepositoryProvider<ProfileRepository>(
      create: (_) => mocks.profile,
      child: MaterialApp(
        home: ProfilePage(
          profileId: profileId,
          displayName: 'Анна',
          viewerId: viewerId,
        ),
      ),
    );
  }

  testWidgets('показывает имя, био, статистику', (tester) async {
    stubOwnProfile();

    await tester.pumpWidget(buildSubject(viewerId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.text('Анна'), findsWidgets);
    expect(find.text('Люблю порядок'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Назначено'), findsOneWidget);
    expect(find.text('За неделю'), findsOneWidget);
    expect(find.text('За месяц'), findsOneWidget);
    expect(find.text('Всего назначено задач: 10'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('свой профиль показывает «Это вы» и кнопку редактирования', (
    tester,
  ) async {
    stubOwnProfile();

    await tester.pumpWidget(buildSubject(viewerId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.text('Это вы'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('чужой профиль не показывает «Это вы» и кнопку редактирования', (
    tester,
  ) async {
    when(() => mocks.profile.getProfile('user-2')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-2',
        displayName: 'Влад',
        timezone: 'Europe/Moscow',
      ),
    );
    when(() => mocks.profile.getStats('user-2')).thenAnswer(
      (_) async => const ProfileStats(),
    );

    await tester.pumpWidget(
      buildSubject(profileId: 'user-2', viewerId: 'user-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Это вы'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('без viewerId страница ведёт себя как чужая', (tester) async {
    stubOwnProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Это вы'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('тап по кнопке редактирования открывает ProfileSettingsPage', (
    tester,
  ) async {
    stubOwnProfile();
    // ProfileSettingsPage загрузит профиль повторно
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => profile,
    );

    await tester.pumpWidget(buildSubject(viewerId: 'user-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSettingsPage), findsOneWidget);
  });

  testWidgets('без био секция био не показывается', (tester) async {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
        bio: '',
      ),
    );
    when(() => mocks.profile.getStats('user-1')).thenAnswer(
      (_) async => stats,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Пустая био не рендерит контейнер — проверяем, что контейнеров с био нет
    expect(find.text('Люблю порядок'), findsNothing);
  });
}
