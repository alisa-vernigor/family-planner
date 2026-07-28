import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/tasks/domain/entities/task.dart';
import 'package:family_planner/features/tasks/domain/entities/create_task_params.dart';
import 'package:family_planner/features/tasks/domain/entities/task_status.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/update_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/uncomplete_task_use_case.dart';
import 'package:family_planner/features/households/domain/entities/household_invitation.dart';

void main() {
  final task = Task(
    id: '1',
    householdId: 'h1',
    title: 'Test',
    estimatedDurationMinutes: 30,
    plannedFor: DateTime(2026, 7, 28),
    allowedMemberIds: const ['m1'],
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 7, 27),
  );

  group('Исключения TaskCompletion', () {
    test('TaskAlreadyCompletedException.toString', () {
      const e = TaskAlreadyCompletedException();
      expect(e.toString(), contains('уже выполнена'));
    });

    test('TaskCompletionNotAllowedException.toString', () {
      const e = TaskCompletionNotAllowedException(taskId: 't1', memberId: 'm1');
      expect(e.toString(), contains('не может выполнить'));
      expect(e.taskId, 't1');
      expect(e.memberId, 'm1');
    });
  });

  group('Исключения CreateTask', () {
    test('TaskTitleEmptyException.toString', () {
      const e = TaskTitleEmptyException();
      expect(e.toString(), contains('не может быть пустым'));
    });

    test('TaskDurationInvalidException.toString', () {
      const e = TaskDurationInvalidException();
      expect(e.toString(), contains('больше нуля'));
    });

    test('TaskRecurrenceWeekdaysEmptyException.toString', () {
      const e = TaskRecurrenceWeekdaysEmptyException();
      expect(e.toString(), contains('выберите дни недели'));
    });

    test('TaskRecurrenceWeekdaysInvalidException.toString', () {
      const e = TaskRecurrenceWeekdaysInvalidException();
      expect(e.toString(), contains('от 1 до 7'));
    });

    test('TaskRecurrenceIntervalInvalidException.toString', () {
      const e = TaskRecurrenceIntervalInvalidException();
      expect(e.toString(), contains('больше нуля'));
    });

    test('TaskRecurrenceDatesInvalidException.toString', () {
      const e = TaskRecurrenceDatesInvalidException();
      expect(e.toString(), contains('дата окончания'));
    });
  });

  group('Исключения Uncomplete', () {
    test('TaskNotCompletedException.toString', () {
      const e = TaskNotCompletedException();
      expect(e.toString(), contains('ещё не выполнена'));
    });
  });

  group('Сущности', () {
    test('HouseholdInvitation props', () {
      final now = DateTime(2026, 7, 28);
      final a = HouseholdInvitation(
        id: 'inv-1', householdId: 'h1', householdName: 'Family',
        invitedByDisplayName: 'Alice', createdAt: now, expiresAt: now,
      );
      // Проверяем Equatable
      expect(a.props, [a.id, a.householdId, a.householdName, a.invitedByDisplayName, a.createdAt, a.expiresAt]);
    });
  });

  group('UpdateTaskUseCase', () {
    test('выбрасывает ArgumentError на пустое название', () async {
      final repo = _FakeRepo();
      expect(
        () => UpdateTaskUseCase(repository: repo)(task: task.copyWith(title: '   ')),
        throwsArgumentError,
      );
    });

    test('выбрасывает ArgumentError на нулевую длительность', () async {
      final repo = _FakeRepo();
      expect(
        () => UpdateTaskUseCase(repository: repo)(task: task.copyWith(estimatedDurationMinutes: 0)),
        throwsArgumentError,
      );
    });
  });
}

final class _FakeRepo implements TaskRepository {
  @override Future<Task> create({required CreateTaskParams params}) => throw UnimplementedError();
  @override Future<void> delete({required String taskId}) async {}
  @override Future<List<Task>> getForDay({required String householdId, required DateTime day}) => Future.value([]);
  @override Future<List<Task>> getScheduledAfter({required String householdId, required DateTime day}) => Future.value([]);
  @override Future<void> save(Task task) async {}
  @override Future<List<Task>> getAllPending({required String householdId}) => Future.value([]);
  @override Future<void> addAllowedMember({required String taskId, required String memberId}) async {}
  @override Future<void> removeAllowedMember({required String taskId, required String memberId}) async {}

  @override
  Future<void> patchStatus({required String taskId, required String status, String? completedByMemberId, String? completedAt, String? assignedMemberId}) async {}
}
