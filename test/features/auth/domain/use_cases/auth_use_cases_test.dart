import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/auth/domain/entities/app_user.dart';
import 'package:family_planner/features/auth/domain/repositories/auth_repository.dart';
import 'package:family_planner/features/auth/domain/use_cases/get_current_user_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_up_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  group('GetCurrentUserUseCase', () {
    const user = AppUser(id: 'user-1', email: 'anna@example.com');

    test('returns user from repository', () {
      when(() => repository.currentUser).thenReturn(user);

      final useCase = GetCurrentUserUseCase(repository: repository);
      final result = useCase();

      expect(result, user);
      verify(() => repository.currentUser).called(1);
    });

    test('returns null when repository returns null', () {
      when(() => repository.currentUser).thenReturn(null);

      final useCase = GetCurrentUserUseCase(repository: repository);
      final result = useCase();

      expect(result, isNull);
      verify(() => repository.currentUser).called(1);
    });
  });

  group('SignInUseCase', () {
    const user = AppUser(id: 'user-1', email: 'anna@example.com');

    test('calls repository.signIn with correct params', () async {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);

      final useCase = SignInUseCase(repository: repository);
      await useCase(email: 'anna@example.com', password: 'password123');

      verify(
        () => repository.signIn(
          email: 'anna@example.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test('returns AppUser', () async {
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);

      final useCase = SignInUseCase(repository: repository);
      final result = await useCase(
        email: 'anna@example.com',
        password: 'password123',
      );

      expect(result, user);
    });
  });

  group('SignOutUseCase', () {
    test('calls repository.signOut', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});

      final useCase = SignOutUseCase(repository: repository);
      await useCase();

      verify(() => repository.signOut()).called(1);
    });
  });

  group('SignUpUseCase', () {
    const user = AppUser(id: 'user-1', email: 'anna@example.com');

    test('calls repository.signUp with correct params', () async {
      when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => user);

      final useCase = SignUpUseCase(repository: repository);
      await useCase(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Anna',
      );

      verify(
        () => repository.signUp(
          email: 'anna@example.com',
          password: 'password123',
          displayName: 'Anna',
        ),
      ).called(1);
    });

    test('returns user when signup succeeds', () async {
      when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => user);

      final useCase = SignUpUseCase(repository: repository);
      final result = await useCase(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Anna',
      );

      expect(result, user);
    });

    test('returns null when signup returns null', () async {
      when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => null);

      final useCase = SignUpUseCase(repository: repository);
      final result = await useCase(
        email: 'anna@example.com',
        password: 'password123',
        displayName: 'Anna',
      );

      expect(result, isNull);
    });
  });
}
