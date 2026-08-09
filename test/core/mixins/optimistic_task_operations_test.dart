import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/core/mixins/optimistic_task_operations.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';

/// Тестовый cubit, встраивающий миксин так же, как TodayTasksCubit/
/// ScheduledTasksCubit (buildLoaded = конструктор Loaded-состояния).
final class _TestCubit extends Cubit<_TestState>
    with OptimisticTaskOperationsMixin<_TestState> {
  _TestCubit() : super(const _TestState(tasks: [], members: []));

  _TestState _build(List<Task> tasks, List<HouseholdMember> members) =>
      _TestState(tasks: tasks, members: members);

  void load(List<Task> tasks, List<HouseholdMember> members) {
    // Как в _loadInternal: сначала filterPendingDeletes, потом emit.
    emit(_build(filterPendingDeletes(tasks), members));
  }

  void replace(Task task, List<Task> current, List<HouseholdMember> members) {
    optimisticReplace(task, current, members, _build);
  }

  void remove(String taskId, List<Task> current, List<HouseholdMember> members) {
    optimisticRemove(taskId, current, members, _build);
  }
}

final class _TestState {
  const _TestState({required this.tasks, required this.members});

  final List<Task> tasks;
  final List<HouseholdMember> members;
}

void main() {
  final day = DateTime(2026, 8, 9);

  Task task(String id, {String title = 'Задача'}) => Task(
        id: id,
        householdId: 'h1',
        title: title,
        estimatedDurationMinutes: 30,
        plannedFor: day,
        allowedMemberIds: const ['m1'],
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 8, 8),
      );

  group('OptimisticTaskOperationsMixin', () {
    test('optimisticReplace заменяет задачу по id, сохраняя порядок', () {
      final cubit = _TestCubit();
      final tasks = [task('a'), task('b'), task('c')];
      final updated = task('b', title: 'Обновлённая');

      cubit.replace(updated, tasks, const []);

      expect(cubit.state.tasks.map((t) => t.title).toList(), [
        'Задача',
        'Обновлённая',
        'Задача',
      ]);
      expect(cubit.state.tasks[1].id, 'b');
      cubit.close();
    });

    test('optimisticReplace с несуществующим id оставляет список без изменений', () {
      final cubit = _TestCubit();
      final tasks = [task('a')];

      cubit.replace(task('zzz'), tasks, const []);

      expect(cubit.state.tasks.length, 1);
      expect(cubit.state.tasks.first.id, 'a');
      cubit.close();
    });

    test('optimisticRemove убирает задачу и ставит её в pending', () {
      final cubit = _TestCubit();
      final tasks = [task('a'), task('b')];

      cubit.remove('a', tasks, const []);

      expect(cubit.state.tasks.map((t) => t.id).toList(), ['b']);

      // refresh с теми же задачами: 'a' ещё в pending → фильтруется.
      cubit.load(tasks, const []);
      expect(cubit.state.tasks.map((t) => t.id).toList(), ['b']);
      cubit.close();
    });

    test('filterPendingDeletes прячет задачу только пока она в pending', () {
      final cubit = _TestCubit();
      final tasks = [task('a'), task('b')];

      cubit.remove('a', tasks, const []);
      cubit.load(tasks, const []);

      // После confirmDelete задача снова появляется.
      cubit.confirmDelete('a');
      cubit.load(tasks, const []);
      expect(cubit.state.tasks.map((t) => t.id).toList(), ['a', 'b']);

      // После cancelDelete — тоже.
      cubit.remove('b', tasks, const []);
      cubit.load(tasks, const []);
      expect(cubit.state.tasks.map((t) => t.id).toList(), ['a']);
      cubit.cancelDelete('b');
      cubit.load(tasks, const []);
      expect(cubit.state.tasks.map((t) => t.id).toList(), ['a', 'b']);
      cubit.close();
    });

    test('filterPendingDeletes с пустым pending возвращает список как есть', () {
      final cubit = _TestCubit();
      final tasks = [task('a')];

      cubit.load(tasks, const []);

      expect(cubit.state.tasks, tasks);
      cubit.close();
    });

    test('порядок optimisticReplace: повторная замена той же задачи', () {
      final cubit = _TestCubit();
      final tasks = [task('a'), task('b')];
      final second = task('a', title: 'Вторая');

      cubit.replace(second, tasks, const []);
      expect(cubit.state.tasks[0].title, 'Вторая');
      cubit.close();
    });
  });
}
