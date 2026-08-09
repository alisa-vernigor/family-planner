import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_cubit.dart';
import 'package:family_planner/features/tasks/presentation/cubit/create_task_state.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository repository;
  late CreateTaskUseCase useCase;
  late CreateTaskCubit cubit;

  final plannedFor = DateTime.utc(2026, 7, 19);

  final params = CreateTaskParams(
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
  );

  final task = Task(
    id: 'task-1',
    householdId: 'household-1',
    title: 'Купить продукты',
    estimatedDurationMinutes: 30,
    plannedFor: plannedFor,
    allowedMemberIds: const ['user-1'],
    status: TaskStatus.pending,
    createdAt: DateTime.utc(2026, 7, 19, 12),
  );

  setUpAll(() {
    registerFallbackValue(
      CreateTaskParams(
        householdId: 'household-1',
        title: 'test',
        estimatedDurationMinutes: 30,
        plannedFor: DateTime.utc(2026, 7, 19),
      ),
    );
  });

  setUp(() {
    repository = MockTaskRepository();
    useCase = CreateTaskUseCase(repository: repository);
    cubit = CreateTaskCubit(createTaskUseCase: useCase);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state is CreateTaskInitial', () {
    expect(cubit.state, const CreateTaskInitial());
  });

  blocTest<CreateTaskCubit, CreateTaskState>(
    'create emits [CreateTaskInProgress, CreateTaskSuccess] with returned task',
    build: () {
      when(
        () => repository.create(params: any(named: 'params')),
      ).thenAnswer((_) async => task);
      return cubit;
    },
    act: (cubit) => cubit.create(params: params),
    expect: () => [const CreateTaskInProgress(), CreateTaskSuccess(task: task)],
  );

  blocTest<CreateTaskCubit, CreateTaskState>(
    'create emits [CreateTaskInProgress, CreateTaskFailure] on exception',
    build: () {
      when(
        () => repository.create(params: any(named: 'params')),
      ).thenThrow(Exception('Ошибка соединения'));
      return cubit;
    },
    act: (cubit) => cubit.create(params: params),
    expect: () => const [
      CreateTaskInProgress(),
      CreateTaskFailure(message: 'Не удалось создать задачу.'),
    ],
  );

  blocTest<CreateTaskCubit, CreateTaskState>(
    'reset returns to CreateTaskInitial',
    build: () => cubit,
    act: (cubit) => cubit.reset(),
    expect: () => [const CreateTaskInitial()],
  );

  blocTest<CreateTaskCubit, CreateTaskState>(
    'create с напоминанием планирует его (ReminderService не инициализирован — '
    'no-op) и завершается Success',
    build: () {
      final taskWithReminder = task.copyWith(reminderMinutesBefore: 15);
      when(
        () => repository.create(params: any(named: 'params')),
      ).thenAnswer((_) async => taskWithReminder);
      return cubit;
    },
    act: (cubit) => cubit.create(params: params),
    expect: () => [
      const CreateTaskInProgress(),
      CreateTaskSuccess(task: task.copyWith(reminderMinutesBefore: 15)),
    ],
  );
}
