import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/features/households/domain/entities/household_invitation.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/households/presentation/pages/household_invitations_page.dart';
import 'package:family_planner/features/notifications/data/notification_read_store.dart';
import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:family_planner/features/notifications/presentation/pages/notifications_page.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_category_params.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_subtask_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/entities/task_subtask.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

import '../../../../helpers/mock_repository_factory.dart';

final class MockTaskSubtaskRepository extends Mock
    implements TaskSubtaskRepository {}

final class MockTaskCategoryRepository extends Mock
    implements TaskCategoryRepository {}

void main() {
  late MockRepositoryFactory mocks;
  late MockTaskSubtaskRepository subtaskRepo;
  late MockTaskCategoryRepository categoryRepo;

  setUpAll(() {
    registerFallbackValue(
      CreateTaskCategoryParams(householdId: 'household-1', name: 'fallback'),
    );
    registerFallbackValue(
      CreateTaskSubtaskParams(taskId: 'fallback', title: 'fallback'),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mocks = MockRepositoryFactory();
    subtaskRepo = MockTaskSubtaskRepository();
    categoryRepo = MockTaskCategoryRepository();
  });

  NotificationItem taskItem({
    String id = 'task-1',
    NotificationKind kind = NotificationKind.taskAssigned,
    DateTime? occurredAt,
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
      occurredAt: occurredAt ?? DateTime.now().subtract(const Duration(hours: 2)),
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
    when(
      () => subtaskRepo.getForTask(any()),
    ).thenAnswer((_) async => const <TaskSubtask>[]);
    when(
      () => categoryRepo.getForHousehold(any()),
    ).thenAnswer((_) async => const <TaskCategory>[]);

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
      child: RepositoryProvider<TaskRepository>(
        create: (_) => mocks.task,
        child: RepositoryProvider<HouseholdRepository>(
          create: (_) => mocks.household,
          child: RepositoryProvider<TaskSubtaskRepository>(
            create: (_) => subtaskRepo,
            child: RepositoryProvider<TaskCategoryRepository>(
              create: (_) => categoryRepo,
              child: MaterialApp(
                home: NotificationsPage(currentMemberId: 'user-1'),
              ),
            ),
          ),
        ),
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

  testWidgets('тап по задаче открывает редактор задачи (showEditTaskSheet)', (
    tester,
  ) async {
    final task = Task(
      id: 'task-1',
      householdId: 'household-1',
      title: 'Задача назначена',
      estimatedDurationMinutes: 30,
      plannedFor: DateTime(2026, 8, 8),
      allowedMemberIds: const ['user-1'],
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 8, 1),
    );
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem()]);
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => [task]);
    when(
      () => mocks.household.getMembers(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Задача назначена'));
    await tester.pumpAndSettle();

    // Редактор задачи (bottom sheet) открыт.
    expect(find.byKey(const Key('edit_task_title_field')), findsOneWidget);
  });

  testWidgets('тап по задаче, которой нет в pending, ничего не открывает', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem()]);
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenAnswer((_) async => const <Task>[]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Задача назначена'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit_task_title_field')), findsNothing);
  });

  testWidgets('тап по задаче при ошибке загрузки не падает', (tester) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem()]);
    when(
      () => mocks.task.getAllPending(householdId: any(named: 'householdId')),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Задача назначена'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('edit_task_title_field')), findsNothing);
  });

  testWidgets('пустая лента показывает старое уведомление с датой', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [
      taskItem(
        id: 'old-task',
        occurredAt: DateTime(2025, 5, 1, 9, 30),
      ),
    ]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('01.05.2025'), findsOneWidget);
  });

  testWidgets('относительное время: только что / минуты / часы / дни', (
    tester,
  ) async {
    final now = DateTime.now();
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [
      taskItem(id: 'just-now', occurredAt: now.subtract(const Duration(seconds: 30))),
      taskItem(id: 'mins', occurredAt: now.subtract(const Duration(minutes: 5))),
      taskItem(id: 'hours', occurredAt: now.subtract(const Duration(hours: 3))),
      taskItem(id: 'days', occurredAt: now.subtract(const Duration(days: 2))),
    ]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    expect(find.text('только что'), findsOneWidget);
    expect(find.text('5 мин назад'), findsOneWidget);
    expect(find.text('3 ч назад'), findsOneWidget);
    expect(find.text('2 дн назад'), findsOneWidget);
  });

  testWidgets('pull-to-refresh на пустой ленте вызывает refresh', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => const <NotificationItem>[]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('Пока нет уведомлений.'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.notifications.getActivityFeed(
        householdId: any(named: 'householdId'),
      ),
    ).called(2);
  });

  testWidgets('pull-to-refresh на ленте с задачами вызывает refresh', (
    tester,
  ) async {
    when(() => mocks.notifications.getActivityFeed(
      householdId: any(named: 'householdId'),
    )).thenAnswer((_) async => [taskItem()]);

    await tester.pumpWidget(
      buildSubject(notificationsCubit: createNotificationsCubit()..load()),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.text('Задача назначена'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(
      () => mocks.notifications.getActivityFeed(
        householdId: any(named: 'householdId'),
      ),
    ).called(2);
  });
}
