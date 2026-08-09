import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/notifications/data/notification_read_store.dart';
import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:family_planner/features/notifications/presentation/pages/notifications_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  late MockRepositoryFactory mocks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
  });

  NotificationItem taskItem({
    String id = 'task-1',
    NotificationKind kind = NotificationKind.taskAssigned,
  }) {
    return NotificationItem(
      id: id,
      kind: kind,
      actorId: 'actor-1',
      actorName: 'Мария',
      title: switch (kind) {
        NotificationKind.taskAssigned => 'Задача назначена',
        NotificationKind.taskCompleted => 'Задача выполнена',
        NotificationKind.taskSkipped => 'Задача пропущена',
        NotificationKind.invitation => 'Приглашение в семью',
      },
      subtitle: kind == NotificationKind.taskAssigned
          ? 'Мария назначила вам задачу «Убраться»'
          : 'Описание',
      occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
      taskId: 'task-1',
      taskStatus: 'pending',
      householdId: 'household-1',
    );
  }

  NotificationItem invitationItem({
    String id = 'inv-1',
    String status = 'pending',
  }) {
    return NotificationItem(
      id: id,
      kind: NotificationKind.invitation,
      actorId: 'actor-2',
      actorName: 'Влад',
      title: 'Приглашение в семью',
      subtitle: 'Влад приглашает вас в семью «Семья Влада»',
      occurredAt: DateTime.now().subtract(const Duration(hours: 1)),
      invitationId: id,
      invitationStatus: status,
      householdId: 'household-2',
    );
  }

  AppNotificationsCubit createNotificationsCubit({
    List<NotificationItem>? notifications,
  }) {
    return AppNotificationsCubit(
      notificationsRepository: mocks.notifications,
      readStore: NotificationReadStore(),
      notifications: notifications,
    );
  }

  Widget buildSubject({
    required AppNotificationsCubit notificationsCubit,
  }) {
    when(
      () => mocks.household.getPendingInvitations(),
    ).thenAnswer((_) async => const <HouseholdInvitation>[]);
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AppNotificationsCubit>.value(
          value: notificationsCubit,
        ),
        BlocProvider<HouseholdInvitationsCubit>(
          create: (_) => HouseholdInvitationsCubit(
            householdRepository: mocks.household,
          ),
        ),
        BlocProvider<HouseholdCubit>(
          create: (_) => HouseholdCubit(
            householdRepository: mocks.household,
          ),
        ),
      ],
      child: MaterialApp(
        home: const NotificationsPage(currentMemberId: 'user-1'),
      ),
    );
  }

  testWidgets('показывает спиннер в состоянии загрузки', (tester) async {
    when(
      () => mocks.notifications.getActivityFeed(
        householdId: any(named: 'householdId'),
      ),
    ).thenAnswer((_) => Completer<List<NotificationItem>>().future);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('пустая лента показывает «Пока нет уведомлений.»', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => const <NotificationItem>[]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пока нет уведомлений.'), findsOneWidget);
  });

  testWidgets('лента с задачами показывает карточки и «Прочитать всё»', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem()]);
    when(() => mocks.notifications.markAllRead()).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Задача назначена'), findsOneWidget);
    expect(
      find.text('Мария назначила вам задачу «Убраться»'),
      findsOneWidget,
    );
    expect(find.text('Прочитать всё'), findsOneWidget);
  });

  testWidgets('«Прочитать всё» вызывает markAllRead и скрывает кнопку', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem(), taskItem(id: 'task-2')]);
    when(() => mocks.notifications.markAllRead()).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Прочитать всё'));
    await tester.pumpAndSettle();

    verify(() => mocks.notifications.markAllRead()).called(1);
    expect(find.text('Прочитать всё'), findsNothing);
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить уведомления.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('«Повторить» повторяет загрузку', (tester) async {
    var fail = true;
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async {
      if (fail) throw Exception('boom');
      return [taskItem()];
    });

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Задача назначена'), findsOneWidget);
  });

  testWidgets('приглашение показывает кнопки «Принять» и «Отклонить»', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [invitationItem()]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
  });

  testWidgets('тап «Принять» вызывает accept и убирает приглашение', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [invitationItem()]);
    when(
      () => mocks.household.acceptInvitation(invitationId: 'inv-1'),
    ).thenAnswer((_) async => 'household-2');
    when(() => mocks.household.getMyHouseholds()).thenAnswer(
      (_) async => const [],
    );

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.acceptInvitation(invitationId: 'inv-1'),
    ).called(1);
    expect(find.text('Пока нет уведомлений.'), findsOneWidget);
  });

  testWidgets('тап «Отклонить» вызывает decline и убирает приглашение', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [invitationItem()]);
    when(
      () => mocks.household.declineInvitation(invitationId: 'inv-1'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    verify(
      () => mocks.household.declineInvitation(invitationId: 'inv-1'),
    ).called(1);
    expect(find.text('Пока нет уведомлений.'), findsOneWidget);
  });

  testWidgets('приглашение с принятым статусом показывает «Приглашение принято»', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [invitationItem(status: 'accepted')]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Приглашение принято'), findsOneWidget);
    expect(find.text('Принять'), findsNothing);
  });

  testWidgets('тап по приглашению открывает HouseholdInvitationsPage', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [invitationItem()]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Приглашение в семью'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdInvitationsPage), findsOneWidget);
  });
}
