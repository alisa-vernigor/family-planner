import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
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

  Widget buildSubject() {
    return RepositoryProvider<ProfileRepository>(
      create: (_) => mocks.profile,
      child: BlocProvider<AuthCubit>(
        create: (_) => AuthCubit(
          authRepository: mocks.auth,
          enableAuthListener: false,
        ),
        child: const MaterialApp(
          home: ProfileSettingsPage(profileId: 'user-1'),
        ),
      ),
    );
  }

  void stubProfile() {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => profile,
    );
  }

  testWidgets('показывает спиннер во время загрузки', (tester) async {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) => Completer<UserProfile>().future,
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('загруженный профиль показывает поля и кнопки', (tester) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Настройки профиля'), findsOneWidget);
    expect(find.text('Отображаемое имя'), findsOneWidget);
    expect(find.text('О себе'), findsOneWidget);
    expect(find.text('Загрузить фото'), findsOneWidget);
    expect(find.text('Сменить пароль'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Люблю порядок'), findsOneWidget);
  });

  testWidgets('кнопка «Сохранить изменения» появляется после изменения', (
    tester,
  ) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // До изменений кнопки нет
    expect(find.text('Сохранить изменения'), findsOneWidget);
    // AppBar action «Сохранить» не показывается
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Сохранить'),
      ),
      findsNothing,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Отображаемое имя'),
      'Анна 2',
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Сохранить'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('пустое имя не даёт сохранить', (tester) async {
    stubProfile();
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Отображаемое имя'),
      '',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    expect(find.text('Имя не может быть пустым.'), findsOneWidget);
  });

  testWidgets('сохранение профиля вызывает updateProfile', (tester) async {
    stubProfile();
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Отображаемое имя'),
      'Анна Петрова',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна Петрова',
        bio: 'Люблю порядок',
      ),
    ).called(1);
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    when(() => mocks.profile.getProfile('user-1')).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('диалог смены пароля: короткий пароль отклоняется', (
    tester,
  ) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сменить пароль'));
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    expect(find.text('Сменить пароль'), findsWidgets);

    // Пустые поля → диалог открыт, пароль < 8
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(
      find.text('Пароль должен содержать минимум 8 символов.'),
      findsOneWidget,
    );
  });

  testWidgets('диалог смены пароля: несовпадающие пароли отклоняются', (
    tester,
  ) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сменить пароль'));
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Новый пароль'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Подтвердите пароль'),
      'password124',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Пароли не совпадают.'), findsOneWidget);
  });

  testWidgets('успешная смена пароля вызывает updatePassword', (tester) async {
    stubProfile();
    when(() => mocks.auth.updatePassword(newPassword: 'password123'))
        .thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сменить пароль'));
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Новый пароль'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Подтвердите пароль'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    verify(() => mocks.auth.updatePassword(newPassword: 'password123'))
        .called(1);
  });
}
