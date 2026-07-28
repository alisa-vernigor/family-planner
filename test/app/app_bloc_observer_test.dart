import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:family_planner/app/app_bloc_observer.dart';

void main() {
  group('AppBlocObserver', () {
    setUp(() {
      Bloc.observer = AppBlocObserver();
    });

    tearDown(() {
      Bloc.observer = _NoOpBlocObserver();
    });

    test('can be created without throwing', () {
      expect(AppBlocObserver.new, returnsNormally);
    });

    test('can be assigned to Bloc.observer without throwing', () {
      expect(
        () {
          Bloc.observer = AppBlocObserver();
        },
        returnsNormally,
      );
    });

    test('handles Cubit onChange via observer without throwing', () {
      expect(
        () {
          final cubit = _TestCubit(0);
          cubit.increment();
          cubit.close();
        },
        returnsNormally,
      );
    });

    test('handles Cubit onError via observer without throwing', () {
      expect(
        () {
          final cubit = _ErrorCubit();
          cubit.triggerError();
          cubit.close();
        },
        returnsNormally,
      );
    });
  });
}

class _TestCubit extends Cubit<int> {
  _TestCubit(int initialState) : super(initialState);

  void increment() => emit(state + 1);
}

class _ErrorCubit extends Cubit<int> {
  _ErrorCubit() : super(0);

  void triggerError() {
    addError(Exception('test error'));
  }
}

class _NoOpBlocObserver extends BlocObserver {}
