import 'package:flutter_test/flutter_test.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/tasks/domain/services/task_schedule.dart';
import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/tasks/domain/use_cases/complete_task_use_case.dart';
import 'package:family_planner/features/tasks/domain/use_cases/create_task_use_case.dart';

void main() {
  group('AppLogger', () {
    test('debug и info не выбрасывают исключения', () {
      expect(() => AppLogger.debug('test'), returnsNormally);
      expect(() => AppLogger.info('test'), returnsNormally);
    });
  });

  group('TaskSchedule', () {
    test('конструктор существует', () {
      // проверяем, что класс можно использовать статически
      final tasks = TaskSchedule.forDay(tasks: [], day: DateTime.now());
      expect(tasks, isEmpty);
    });
  });

  group('Household', () {
    test('создаётся с id и name', () {
      const h = Household(id: '1', name: 'Test');
      expect(h.id, '1');
      expect(h.name, 'Test');
    });
  });

  group('HouseholdMember', () {
    test('isOwner возвращает true для owner', () {
      const m = HouseholdMember(profileId: '1', displayName: 'A', role: 'owner');
      expect(m.isOwner, isTrue);
    });

    test('isOwner возвращает false для member', () {
      const m = HouseholdMember(profileId: '1', displayName: 'A', role: 'member');
      expect(m.isOwner, isFalse);
    });
  });

  group('CompleteTaskUseCase исключения', () {
    test('toString содержит описания', () {
      expect(
        const TaskAlreadyCompletedException().toString(),
        contains('уже выполнена'),
      );
      expect(
        const TaskCompletionNotAllowedException(taskId: 't1', memberId: 'm1').toString(),
        contains('не может выполнить'),
      );
    });
  });

  group('CreateTaskUseCase исключения', () {
    test('toString содержит описания', () {
      expect(const TaskTitleEmptyException().toString(), contains('не может быть пустым'));
      expect(const TaskDurationInvalidException().toString(), contains('больше нуля'));
    });
  });
}
