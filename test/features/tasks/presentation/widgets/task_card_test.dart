import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_page.dart';
import 'package:family_planner/features/tasks/domain/entities/eisenhower_priority.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_category.dart';
import 'package:family_planner/features/tasks/domain/entities/task_recurrence.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/presentation/widgets/task_card.dart';

import '../../../../helpers/load_roboto_font.dart';
import '../../../../helpers/mock_repository_factory.dart';

void main() {
  setUpAll(loadRobotoFont);

  final member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Анна',
    role: 'member',
  );
  final otherMember = HouseholdMember(
    profileId: 'user-2',
    displayName: 'Влад',
    role: 'owner',
  );

  final baseTask = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    description: 'Сходить в магазин вечером',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 8, 10),
    deadline: DateTime(2026, 8, 12, 18),
    allowedMemberIds: const ['user-1'],
    assignedMemberId: 'user-1',
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 1),
    priority: EisenhowerPriority.urgentImportant,
  );

  Widget buildSubject({
    Task? task,
    List<HouseholdMember>? members,
    String? currentMemberId,
    VoidCallback? onComplete,
    VoidCallback? onUncomplete,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onAssign,
    VoidCallback? onTogglePin,
    VoidCallback? onReschedule,
    VoidCallback? onDuplicate,
    VoidCallback? onTogglePause,
    VoidCallback? onSkip,
    TaskCategory? category,
    bool isSelected = false,
    VoidCallback? onLongPress,
    VoidCallback? onSwipeComplete,
    VoidCallback? onSwipeUncomplete,
    VoidCallback? onSwipeDelete,
    MockRepositoryFactory? mock,
  }) {
    return MockRepoProvider(
      mock: mock,
      child: MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task ?? baseTask,
            members: members ?? [member, otherMember],
            currentMemberId: currentMemberId ?? 'user-1',
            onComplete: onComplete ?? () {},
            onUncomplete: onUncomplete ?? () {},
            onEdit: onEdit ?? () {},
            onDelete: onDelete ?? () {},
            onAssign: onAssign ?? () {},
            onTogglePin: onTogglePin,
            onReschedule: onReschedule,
            onDuplicate: onDuplicate,
            onTogglePause: onTogglePause,
            onSkip: onSkip,
            category: category,
            isSelected: isSelected,
            onLongPress: onLongPress,
            onSwipeComplete: onSwipeComplete,
            onSwipeUncomplete: onSwipeUncomplete,
            onSwipeDelete: onSwipeDelete,
          ),
        ),
      ),
    );
  }

  testWidgets('показывает заголовок, описание, длительность', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Купить продукты'), findsOneWidget);
    expect(find.text('Сходить в магазин вечером'), findsOneWidget);
    expect(find.text('30 мин'), findsOneWidget);
  });

  testWidgets('completed-задача зачёркнута и показывает uncomplete-кнопку', (
    tester,
  ) async {
    final completed = baseTask.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 2),
    );
    await tester.pumpWidget(buildSubject(task: completed));

    final title = tester.widget<Text>(find.text('Купить продукты'));
    expect(title.style?.decoration, TextDecoration.lineThrough);

    expect(
      find.byKey(const Key('uncomplete_task_button_task-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('complete_task_button_task-1')), findsNothing);
  });

  testWidgets('кнопка complete вызывает onComplete', (tester) async {
    var completed = false;
    await tester.pumpWidget(buildSubject(onComplete: () => completed = true));

    await tester.tap(find.byKey(const Key('complete_task_button_task-1')));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('кнопка uncomplete вызывает onUncomplete', (tester) async {
    final completed = baseTask.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 2),
    );
    var uncompleted = false;
    await tester.pumpWidget(
      buildSubject(task: completed, onUncomplete: () => uncompleted = true),
    );

    await tester.tap(find.byKey(const Key('uncomplete_task_button_task-1')));
    await tester.pump();

    expect(uncompleted, isTrue);
  });

  testWidgets('пользователь вне allowedMemberIds не может завершить', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      buildSubject(
        currentMemberId: 'other-user',
        onComplete: () => completed = true,
      ),
    );

    final button = tester.widget<IconButton>(
      find.byKey(const Key('complete_task_button_task-1')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('complete_task_button_task-1')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(completed, isFalse);
  });

  testWidgets('категория показывается чипом', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        category: const TaskCategory(
          id: 'cat-1',
          householdId: 'household-1',
          name: 'Покупки',
          colorHex: 'E53935',
        ),
      ),
    );

    expect(find.text('Покупки'), findsOneWidget);
  });

  testWidgets('повторяющаяся задача показывает бейдж «Повтор»', (tester) async {
    final recurring = baseTask.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
    );
    await tester.pumpWidget(buildSubject(task: recurring));

    expect(find.text('Повтор'), findsOneWidget);
  });

  testWidgets('серия на паузе показывает бейдж', (tester) async {
    final paused = baseTask.copyWith(
      templateId: 'template-1',
      recurrence: const TaskRecurrence.daily(),
      templateActive: false,
    );
    await tester.pumpWidget(buildSubject(task: paused));

    expect(find.text('Серия на паузе'), findsOneWidget);
  });

  testWidgets('закреплённая задача показывает «Закреплено»', (tester) async {
    final pinned = baseTask.copyWith(pinnedMemberId: 'user-1');
    await tester.pumpWidget(buildSubject(task: pinned));

    expect(find.text('Закреплено'), findsOneWidget);
  });

  testWidgets('показывает чип приоритета', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Срочно и важно'), findsOneWidget);
  });

  testWidgets('показывает чип приоритета не-срочно-важно', (tester) async {
    final task = baseTask.copyWith(
      priority: EisenhowerPriority.notUrgentImportant,
    );
    await tester.pumpWidget(buildSubject(task: task));

    expect(find.text('Не срочно, но важно'), findsOneWidget);
  });

  testWidgets('показывает чип приоритета срочно-не-важно', (tester) async {
    final task = baseTask.copyWith(
      priority: EisenhowerPriority.urgentNotImportant,
    );
    await tester.pumpWidget(buildSubject(task: task));

    expect(find.text('Срочно, но не важно'), findsOneWidget);
  });

  testWidgets('показывает чип приоритета не-срочно-не-важно', (tester) async {
    final task = baseTask.copyWith(
      priority: EisenhowerPriority.notUrgentNotImportant,
    );
    await tester.pumpWidget(buildSubject(task: task));

    expect(find.text('Не срочно и не важно'), findsOneWidget);
  });

  testWidgets('исполнитель-я показывает «Я»', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Я'), findsOneWidget);
  });

  testWidgets('исполнитель другой — показывает имя', (tester) async {
    final assignedToOther = baseTask.copyWith(assignedMemberId: 'user-2');
    await tester.pumpWidget(buildSubject(task: assignedToOther));

    expect(find.text('Влад'), findsOneWidget);
  });

  testWidgets('исполнитель вне списка показывает «Участник»', (tester) async {
    final ghost = baseTask.copyWith(assignedMemberId: 'ghost');
    await tester.pumpWidget(buildSubject(task: ghost));

    expect(find.text('Участник'), findsOneWidget);
  });

  testWidgets('без исполнителя нет assignee-чипа', (tester) async {
    final unassigned = baseTask.copyWith(assignedMemberId: null);
    await tester.pumpWidget(buildSubject(task: unassigned));

    expect(find.text('Участник'), findsNothing);
    expect(find.text('Я'), findsNothing);
  });

  testWidgets('дата создания показывается в формате дд.мм', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('01.08'), findsOneWidget);
  });

  group('меню действий', () {
    void enlargeSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('edit через меню', (tester) async {
      enlargeSurface(tester);
      var edited = false;
      await tester.pumpWidget(buildSubject(onEdit: () => edited = true));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();

      expect(edited, isTrue);
    });

    testWidgets('delete через меню', (tester) async {
      enlargeSurface(tester);
      var deleted = false;
      await tester.pumpWidget(buildSubject(onDelete: () => deleted = true));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('assign через меню', (tester) async {
      enlargeSurface(tester);
      var assigned = false;
      await tester.pumpWidget(buildSubject(onAssign: () => assigned = true));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();

      expect(assigned, isTrue);
    });

    testWidgets('перенос/дублирование/пауза/пропуск при наличии колбэков', (
      tester,
    ) async {
      enlargeSurface(tester);
      await tester.pumpWidget(
        buildSubject(
          onReschedule: () {},
          onDuplicate: () {},
          onTogglePause: () {},
          onSkip: () {},
        ),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();

      expect(find.text('Перенести'), findsOneWidget);
      expect(find.text('Дублировать'), findsOneWidget);
      expect(find.text('Поставить на паузу'), findsOneWidget);
      expect(find.text('Пропустить'), findsOneWidget);
    });

    testWidgets('серия на паузе в меню показывает «Возобновить серию»', (
      tester,
    ) async {
      enlargeSurface(tester);
      final paused = baseTask.copyWith(
        templateId: 'template-1',
        recurrence: const TaskRecurrence.daily(),
        templateActive: false,
      );
      await tester.pumpWidget(
        buildSubject(task: paused, onTogglePause: () {}),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();

      expect(find.text('Возобновить серию'), findsOneWidget);
    });

    testWidgets('togglePause вызывает колбэк', (tester) async {
      enlargeSurface(tester);
      var paused = false;
      await tester.pumpWidget(
        buildSubject(
          onTogglePause: () => paused = true,
        ),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Поставить на паузу'));
      await tester.pumpAndSettle();

      expect(paused, isTrue);
    });

    testWidgets('pin вызывает onTogglePin для закреплённой задачи', (
      tester,
    ) async {
      enlargeSurface(tester);
      final pinned = baseTask.copyWith(pinnedMemberId: 'user-1');
      var unpinned = false;
      await tester.pumpWidget(
        buildSubject(task: pinned, onTogglePin: () => unpinned = true),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открепить'));
      await tester.pumpAndSettle();

      expect(unpinned, isTrue);
    });

    testWidgets('reschedule вызывает колбэк', (tester) async {
      enlargeSurface(tester);
      var rescheduled = false;
      await tester.pumpWidget(
        buildSubject(onReschedule: () => rescheduled = true),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Перенести'));
      await tester.pumpAndSettle();

      expect(rescheduled, isTrue);
    });

    testWidgets('duplicate вызывает колбэк', (tester) async {
      enlargeSurface(tester);
      var duplicated = false;
      await tester.pumpWidget(
        buildSubject(onDuplicate: () => duplicated = true),
      );

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дублировать'));
      await tester.pumpAndSettle();

      expect(duplicated, isTrue);
    });

    testWidgets('skip вызывает колбэк', (tester) async {
      enlargeSurface(tester);
      var skipped = false;
      await tester.pumpWidget(buildSubject(onSkip: () => skipped = true));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
    });

    testWidgets('закреплённая задача показывает «Открепить» и «Изменить ответственного»', (
      tester,
    ) async {
      enlargeSurface(tester);
      final pinned = baseTask.copyWith(pinnedMemberId: 'user-1');
      await tester.pumpWidget(buildSubject(task: pinned));

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();

      expect(find.text('Открепить'), findsOneWidget);
      expect(find.text('Изменить ответственного'), findsOneWidget);
    });

    testWidgets('обычная задача не показывает доп. пункты', (tester) async {
      enlargeSurface(tester);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byTooltip('Действия'));
      await tester.pumpAndSettle();

      expect(find.text('Перенести'), findsNothing);
      expect(find.text('Дублировать'), findsNothing);
      expect(find.text('Пропустить'), findsNothing);
      expect(find.text('Поставить на паузу'), findsNothing);
    });
  });

  group('свайпы', () {
    testWidgets('свайп вправо для pending вызывает onSwipeComplete', (
      tester,
    ) async {
      var swipeComplete = false;
      await tester.pumpWidget(
        buildSubject(onSwipeComplete: () => swipeComplete = true),
      );

      await tester.drag(find.text('Купить продукты'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(swipeComplete, isTrue);
      expect(find.text('Купить продукты'), findsOneWidget);
    });

    testWidgets('свайп влево для pending вызывает onSwipeDelete', (
      tester,
    ) async {
      var swipeDelete = false;
      await tester.pumpWidget(
        buildSubject(onSwipeDelete: () => swipeDelete = true),
      );

      await tester.drag(find.text('Купить продукты'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(swipeDelete, isTrue);
      expect(find.text('Купить продукты'), findsOneWidget);
    });

    testWidgets('свайп вправо для completed вызывает onSwipeUncomplete', (
      tester,
    ) async {
      final completed = baseTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 8, 2),
      );
      var swipeUncomplete = false;
      await tester.pumpWidget(
        buildSubject(
          task: completed,
          onSwipeUncomplete: () => swipeUncomplete = true,
        ),
      );

      await tester.drag(find.text('Купить продукты'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(swipeUncomplete, isTrue);
    });

    testWidgets('свайпы неактивны без колбэков', (tester) async {
      await tester.pumpWidget(buildSubject());

      final dismissible = tester.widget<Dismissible>(
        find.byKey(const ValueKey('swipe-task-1')),
      );
      expect(dismissible.direction, DismissDirection.none);
    });
  });

  group('выбор и long-press', () {
    testWidgets('isSelected=true не вызывает onComplete по тапу', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        buildSubject(isSelected: true, onComplete: () => completed = true),
      );

      // Тап по заголовку в режиме выбора ничего не делает.
      await tester.tap(find.text('Купить продукты'), warnIfMissed: false);
      await tester.pump();

      expect(completed, isFalse);
    });

    testWidgets('long press вызывает onLongPress', (tester) async {
      Task? longPressed;
      await tester.pumpWidget(
        buildSubject(onLongPress: () => longPressed = baseTask),
      );

      await tester.longPress(find.text('Купить продукты'));
      await tester.pump();

      expect(longPressed, isNotNull);
    });
  });

  group('состояния карточки', () {
    testWidgets('просроченная задача получает фон errorContainer', (
      tester,
    ) async {
      final overdue = baseTask.copyWith(
        deadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await tester.pumpWidget(buildSubject(task: overdue));

      // Просроченная карточка помечена бейджем дедлайна (deadline chip).
      expect(find.textContaining('до'), findsOneWidget);
    });

    testWidgets('время начала показывает чип plannedTimeLabel', (
      tester,
    ) async {
      final withTime = baseTask.copyWith(plannedTime: const Duration(hours: 9));
      await tester.pumpWidget(buildSubject(task: withTime));

      expect(find.text('09:00'), findsOneWidget);
    });
  });

  group('дедлайн-чип', () {
    testWidgets('дедлайн сегодня показывает «до ЧЧ:ММ»', (tester) async {
      final now = DateTime.now();
      final todayDeadline = DateTime(
        now.year,
        now.month,
        now.day,
        18,
        30,
      );
      await tester.pumpWidget(buildSubject(task: baseTask.copyWith(deadline: todayDeadline)));

      expect(find.text('до 18:30'), findsOneWidget);
    });

    testWidgets('дедлайн сегодня и срочный (< 24ч) показывает warning-иконку', (
      tester,
    ) async {
      final now = DateTime.now();
      final urgentDeadline = now.add(const Duration(hours: 2));
      await tester.pumpWidget(buildSubject(task: baseTask.copyWith(deadline: urgentDeadline)));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('аватар исполнителя и профиль', () {
    testWidgets('аватар по URL показывает NetworkImage', (tester) async {
      final mocks = MockRepositoryFactory();
      final withAvatar = HouseholdMember(
        profileId: 'user-2',
        displayName: 'Влад',
        avatarUrl: 'https://example.com/vlad.png',
        role: 'owner',
      );

      debugNetworkImageHttpClientProvider = () => _FakeHttpClient();

      await tester.pumpWidget(
        buildSubject(
          task: baseTask.copyWith(assignedMemberId: 'user-2'),
          members: [member, withAvatar],
          mock: mocks,
        ),
      );
      await tester.pump();

      final circleAvatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar),
      );
      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
      // Инициалы не показаны при аватаре.
      expect(find.text('В'), findsNothing);

      // Сбрасываем ДО конца теста (иначе invariant-проверка упадёт).
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('тап по assignee открывает ProfilePage', (tester) async {
      final mocks = MockRepositoryFactory();
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
        buildSubject(
          task: baseTask.copyWith(assignedMemberId: 'user-2'),
          mock: mocks,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Влад'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });
}

/// Оборачивает в RepositoryProvider&lt;ProfileRepository&gt; для _AssigneeChip.
final class MockRepoProvider extends StatelessWidget {
  const MockRepoProvider({required this.child, this.mock, super.key});

  final Widget child;
  final MockRepositoryFactory? mock;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProfileRepository>(
      create: (_) => mock?.profile ?? MockProfileRepository(),
      child: child,
    );
  }
}

/// Фейковый HttpClient, возвращающий прозрачный PNG, чтобы NetworkImage
/// не падал в widget-тестах.
final class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  bool autoUncompress = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpClientResponse implements HttpClientResponse {
  static final Uint8List _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _pngBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_pngBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
