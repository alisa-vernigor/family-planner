import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';

// ── Mock classes ────────────────────────────────────────────

final class MockAuthRepository extends Mock implements AuthRepository {}
final class MockHouseholdRepository extends Mock implements HouseholdRepository {}
final class MockProfileRepository extends Mock implements ProfileRepository {}
final class MockTaskRepository extends Mock implements TaskRepository {}

// ── Factory ─────────────────────────────────────────────────

/// Единая фабрика моков для всех тестов.
///
/// Использование:
/// ```dart
/// final mocks = MockRepositoryFactory();
/// final cubit = MyCubit(taskRepository: mocks.task, ...);
/// ```
///
/// Упрощение для нейронок: один класс вместо N mock-деклараций
/// и повторяющегося кода создания в каждом тесте.
final class MockRepositoryFactory {
  MockRepositoryFactory() {
    auth = MockAuthRepository();
    household = MockHouseholdRepository();
    profile = MockProfileRepository();
    task = MockTaskRepository();
  }

  late final MockAuthRepository auth;
  late final MockHouseholdRepository household;
  late final MockProfileRepository profile;
  late final MockTaskRepository task;
}
