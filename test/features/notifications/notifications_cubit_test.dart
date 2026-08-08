import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/features/notifications/data/notification_read_store.dart';
import 'package:family_planner/features/notifications/domain/entities/notification_item.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:family_planner/features/notifications/presentation/cubit/notifications_state.dart';

import '../../helpers/mock_repository_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockRepositoryFactory().notifications;
  });

  NotificationItem item(
    String id, {
    NotificationKind kind = NotificationKind.taskAssigned,
    DateTime? occurredAt,
  }) {
    return NotificationItem(
      id: id,
      kind: kind,
      actorId: 'actor-1',
      actorName: 'Мария',
      title: kind == NotificationKind.taskAssigned
          ? 'Задача назначена'
          : kind == NotificationKind.taskCompleted
          ? 'Задача выполнена'
          : kind == NotificationKind.taskSkipped
          ? 'Задача пропущена'
          : 'Приглашение в семью',
      subtitle: 'Описание',
      occurredAt: occurredAt ?? DateTime(2026, 8, 8, 10),
      taskId: kind == NotificationKind.invitation ? null : 'task-$id',
      taskStatus: 'pending',
      invitationId: kind == NotificationKind.invitation ? 'inv-$id' : null,
      invitationStatus: kind == NotificationKind.invitation ? 'pending' : null,
      householdId: 'household-1',
    );
  }

  AppNotificationsCubit createCubit({List<NotificationItem>? notifications}) {
    return AppNotificationsCubit(
      notificationsRepository: repository,
      readStore: NotificationReadStore(),
      notifications: notifications,
    );
  }

  group('AppNotificationsCubit', () {
    test('initial state is NotificationsInitial', () {
      final cubit = createCubit();
      expect(cubit.state, const NotificationsInitial());
      expect(cubit.unreadCount, 0);
    });

    blocTest<AppNotificationsCubit, NotificationsState>(
      'load загружает ленту и помечает все как непрочитанные',
      build: () {
        when(
          () => repository.getActivityFeed(householdId: any(named: 'householdId')),
        ).thenAnswer((_) async => [item('1'), item('2')]);
        return createCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotificationsLoading(),
        NotificationsLoaded(
          items: [item('1'), item('2')],
          readIds: const {},
        ),
      ],
    );

    blocTest<AppNotificationsCubit, NotificationsState>(
      'markAllRead помечает все как прочитанные',
      build: () {
        when(() => repository.markAllRead()).thenAnswer((_) async {});
        return createCubit(
          notifications: [item('1'), item('2')],
        );
      },
      act: (cubit) async {
        await cubit.markAllRead();
      },
      expect: () => [
        NotificationsLoaded(
          items: [item('1'), item('2')],
          readIds: const {'1', '2'},
        ),
      ],
    );

    blocTest<AppNotificationsCubit, NotificationsState>(
      'markAllRead персистится в стор и виден после refresh',
      build: () {
        when(() => repository.markAllRead()).thenAnswer((_) async {});
        when(
          () => repository.getActivityFeed(householdId: any(named: 'householdId')),
        ).thenAnswer((_) async => [item('1')]);
        return createCubit(
          notifications: [item('1')],
        );
      },
      act: (cubit) async {
        await cubit.markAllRead();
        await cubit.refresh();
      },
      expect: () => [
        NotificationsLoaded(items: [item('1')], readIds: const {'1'}),
      ],
    );

    blocTest<AppNotificationsCubit, NotificationsState>(
      'removeItem убирает событие из ленты',
      build: () => createCubit(
        notifications: [item('1'), item('2')],
      ),
      act: (cubit) => cubit.removeItem('1'),
      expect: () => [
        NotificationsLoaded(items: [item('2')], readIds: const {}),
      ],
    );

    blocTest<AppNotificationsCubit, NotificationsState>(
      'unreadCount считает непрочитанные',
      build: () => createCubit(
        notifications: [item('1'), item('2')],
      ),
      verify: (cubit) {
        expect(cubit.unreadCount, 2);
      },
    );

    blocTest<AppNotificationsCubit, NotificationsState>(
      'load при ошибке → Failure',
      build: () {
        when(
          () => repository.getActivityFeed(householdId: any(named: 'householdId')),
        ).thenThrow(Exception('boom'));
        return createCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotificationsLoading(),
        const NotificationsFailure(message: 'Не удалось загрузить уведомления.'),
      ],
    );
  });
}
