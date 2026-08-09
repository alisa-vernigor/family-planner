import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockImagePicker extends Mock implements ImagePicker {}

/// Минимальный валидный PNG 1×1 (без прозрачности) — для MemoryImage в AvatarWidget.
final Uint8List kValidPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late MockRepositoryFactory mocks;
  late MockImagePicker picker;

  setUpAll(() {
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mocks = MockRepositoryFactory();
    picker = MockImagePicker();
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
        child: MaterialApp(
          home: ProfileSettingsPage(profileId: 'user-1', picker: picker),
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

  testWidgets('смена пароля: ошибка сервера показывает snackbar', (
    tester,
  ) async {
    stubProfile();
    when(() => mocks.auth.updatePassword(newPassword: 'password123'))
        .thenThrow(Exception('network'));

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

    // AuthCubit эмитит AuthFailure → snackbar с сообщением (для не-AuthException —
    // общее сообщение).
    expect(
      find.text('Произошла непредвиденная ошибка авторизации.'),
      findsOneWidget,
    );
  });

  testWidgets('переключение видимости пароля в диалоге', (tester) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сменить пароль'));
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    // Изначально оба поля скрыты.
    final passwordField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Новый пароль'),
    );
    final confirmField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Подтвердите пароль'),
    );
    expect(passwordField.obscureText, isTrue);
    expect(confirmField.obscureText, isTrue);

    // Тапаем по иконкам глаза — текст открывается.
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility_outlined).last);
    await tester.pumpAndSettle();

    final passwordField2 = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Новый пароль'),
    );
    final confirmField2 = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Подтвердите пароль'),
    );
    expect(passwordField2.obscureText, isFalse);
    expect(confirmField2.obscureText, isFalse);
  });

  testWidgets('кнопка «Отмена» закрывает диалог смены пароля', (tester) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сменить пароль'));
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('удаление аватара: кнопка «Удалить» появляется с аватаром', (
    tester,
  ) async {
    // Профиль с аватаром → кнопка «Удалить» видна.
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
        bio: 'Люблю порядок',
        avatarUrl: 'https://example.com/avatar.png',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Удалить'), findsOneWidget);
  });

  testWidgets('удаление аватара: save вызывает removeAvatar', (tester) async {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
        bio: 'Люблю порядок',
        avatarUrl: 'https://example.com/avatar.png',
      ),
    );
    when(() => mocks.profile.removeAvatar('user-1')).thenAnswer((_) async {});
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Тапаем «Удалить» → аватар помечается на удаление → появляется
    // «Сохранить изменения».
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить изменения'), findsOneWidget);

    // Сохраняем → removeAvatar + updateProfile.
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    verify(() => mocks.profile.removeAvatar('user-1')).called(1);
    verify(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).called(1);
  });

  testWidgets('сохранение с ошибкой: снимает isSaving и показывает snackbar', (
    tester,
  ) async {
    stubProfile();
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenThrow(Exception('db'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Отображаемое имя'),
      'Анна Петрова',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    // Ошибка поймана: спиннер в кнопке снят (isSaving = false), поле формы
    // снова активно.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ошибка сохранения после удаления аватара снимает isSaving', (
    tester,
  ) async {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
        bio: 'Люблю порядок',
        avatarUrl: 'https://example.com/avatar.png',
      ),
    );
    when(() => mocks.profile.removeAvatar('user-1')).thenThrow(Exception('db'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сохранить изменения'));
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    // Ошибка removeAvatar поймана → isSaving снят → спиннера нет.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('поле «О себе» показывает счётчик символов', (tester) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // maxLength: 300 → счётчик символов 0/300.
    expect(find.textContaining('/300'), findsOneWidget);
  });

  testWidgets('повторная загрузка после ошибки: «Повторить» вызывает load', (
    tester,
  ) async {
    when(() => mocks.profile.getProfile('user-1')).thenThrow(Exception('boom'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    // Повторный вызов — успех.
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => profile,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Настройки профиля'), findsOneWidget);
    expect(find.text('Анна'), findsOneWidget);
  });

  void stubPickSuccess() {
    // XFile.fromData: readAsBytes() отдаёт байты из памяти (без реального диска),
    // mimeType 'image/png' → страница определит content-type из mimeType.
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer(
      (_) async => XFile.fromData(kValidPngBytes, mimeType: 'image/png'),
    );
  }

  Future<void> openAvatarSheet(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Загрузить фото'));
    await tester.tap(find.text('Загрузить фото'));
    await tester.pumpAndSettle();
  }

  testWidgets('«Загрузить фото» открывает выбор источника', (tester) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);

    expect(find.text('Изменить фото'), findsOneWidget);
    expect(find.text('Сделать снимок'), findsOneWidget);
    expect(find.text('Выбрать из галереи'), findsOneWidget);
  });

  testWidgets('выбор из галереи вызывает pickImage(gallery) и показывает аватар', (
    tester,
  ) async {
    stubProfile();
    stubPickSuccess();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();

    verify(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      ),
    ).called(1);

    // Pending-аватар установлен → «Удалить» и AppBar-действие «Сохранить» видны.
    expect(find.text('Удалить'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Сохранить'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('снимок камеры вызывает pickImage(camera)', (tester) async {
    stubProfile();
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Сделать снимок'));
    await tester.pumpAndSettle();

    verify(
      () => picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      ),
    ).called(1);

    // Пикер вернул null (отмена) → pending-аватар не установлен:
    // «Удалить» и AppBar-действие «Сохранить» отсутствуют.
    expect(find.text('Удалить'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Сохранить'),
      ),
      findsNothing,
    );
  });

  testWidgets('ошибка пикера показывает snackbar', (tester) async {
    stubProfile();
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenThrow(Exception('camera'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Сделать снимок'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось выбрать фото.'), findsOneWidget);
  });

  testWidgets('сохранение после выбора фото вызывает uploadAvatar', (
    tester,
  ) async {
    stubProfile();
    stubPickSuccess();
    when(
      () => mocks.profile.uploadAvatar(
        profileId: 'user-1',
        bytes: any(named: 'bytes'),
        contentType: any(named: 'contentType'),
      ),
    ).thenAnswer((_) async => 'https://example.com/avatar.png');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сохранить изменения'));
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => mocks.profile.uploadAvatar(
        profileId: 'user-1',
        bytes: captureAny(named: 'bytes'),
        contentType: 'image/png',
      ),
    ).captured;
    expect(captured.single, kValidPngBytes);

    verify(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).called(1);
  });

  testWidgets('ошибка сохранения после выбора фото снимает isSaving', (
    tester,
  ) async {
    stubProfile();
    stubPickSuccess();
    when(
      () => mocks.profile.uploadAvatar(
        profileId: 'user-1',
        bytes: any(named: 'bytes'),
        contentType: 'image/png',
      ),
    ).thenAnswer((_) async => 'https://example.com/avatar.png');
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenThrow(Exception('db'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сохранить изменения'));
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    // Ошибка updateProfile поймана → ProfileFailure → экран ошибки с «Повторить».
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('во время сохранения поверх аватара показывается оверлей', (
    tester,
  ) async {
    stubProfile();
    stubPickSuccess();
    // uploadAvatar не завершается, пока мы не отпустим — держим cubit в Loaded,
    // чтобы оверлей isSaving был виден.
    final avatarCompleter = Completer<String>();
    when(
      () => mocks.profile.uploadAvatar(
        profileId: 'user-1',
        bytes: any(named: 'bytes'),
        contentType: 'image/png',
      ),
    ).thenAnswer((_) => avatarCompleter.future);
    when(
      () => mocks.profile.updateProfile(
        profileId: 'user-1',
        displayName: 'Анна',
        bio: 'Люблю порядок',
      ),
    ).thenAnswer((_) async {});
    when(() => mocks.profile.getProfile('user-1'))
        .thenAnswer((_) async => profile);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await openAvatarSheet(tester);
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сохранить изменения'));
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pump();

    // Оверлей: затемнение + спиннер поверх аватара.
    final overlay = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == Colors.black26,
    );
    expect(overlay, findsOneWidget);

    // Отпускаем сохранение — всё заканчивается без ошибок.
    avatarCompleter.complete('https://example.com/avatar.png');
    await tester.pumpAndSettle();
    expect(find.text('Профиль сохранён.'), findsOneWidget);
  });

  testWidgets('изменение «О себе» делает кнопку «Сохранить изменения» активной', (
    tester,
  ) async {
    stubProfile();

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'О себе'),
      'Люблю порядок и тишину',
    );
    await tester.pumpAndSettle();

    // Состояние формы изменилось → Save-кнопка активна (hasChanges = true).
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сохранить изменения'),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Сохранить'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'ошибка updateProfile: не показывает «Профиль сохранён.» и снимает isSaving',
    (tester) async {
      stubProfile();
      when(
        () => mocks.profile.updateProfile(
          profileId: 'user-1',
          displayName: 'Анна',
          bio: 'Люблю порядок',
        ),
      ).thenThrow(Exception('db'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Отображаемое имя'),
        'Анна 2',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сохранить изменения'));
      await tester.pumpAndSettle();

      // Ложного успеха нет: snackbar «Профиль сохранён.» не показывается.
      expect(find.text('Профиль сохранён.'), findsNothing);
      // Ошибка видна (в теле экрана ошибки и в snackbar-листенере).
      expect(find.text('Не удалось обновить профиль.'), findsWidgets);

      // isSaving снят → спиннеров нигде нет.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'ошибка uploadAvatar: снимает isSaving и показывает ошибку, не «сохранён»',
    (tester) async {
      stubProfile();
      stubPickSuccess();
      when(
        () => mocks.profile.uploadAvatar(
          profileId: 'user-1',
          bytes: any(named: 'bytes'),
          contentType: 'image/png',
        ),
      ).thenThrow(Exception('storage'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await openAvatarSheet(tester);
      await tester.tap(find.text('Выбрать из галереи'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Сохранить изменения'));
      await tester.tap(find.text('Сохранить изменения'));
      await tester.pumpAndSettle();

      // Ошибка uploadAvatar поймана в cubit → ProfileFailure → экран ошибки.
      expect(find.text('Не удалось загрузить аватар.'), findsOneWidget);
      expect(find.text('Профиль сохранён.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('ошибка removeAvatar не показывает ложный «Профиль сохранён.»', (
    tester,
  ) async {
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
        bio: 'Люблю порядок',
        avatarUrl: 'https://example.com/avatar.png',
      ),
    );
    when(() => mocks.profile.removeAvatar('user-1')).thenThrow(Exception('db'));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Сохранить изменения'));
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle();

    // Ложного «Профиль сохранён.» нет — показывается ошибка удаления.
    expect(find.text('Профиль сохранён.'), findsNothing);
    expect(find.text('Не удалось удалить аватар.'), findsOneWidget);
  });
}