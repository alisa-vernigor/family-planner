import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/households/domain/entities/household.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';

void main() {
  const household1 = Household(id: '1', name: 'Семья Ивановых');
  const household2 = Household(id: '2', name: 'Семья Петровых');

  group('HouseholdState sealed class', () {
    group('все состояния создаются корректно', () {
      test('HouseholdInitial', () {
        const state = HouseholdInitial();
        expect(state, isA<HouseholdState>());
        expect(state.props, isEmpty);
      });

      test('HouseholdLoading', () {
        const state = HouseholdLoading();
        expect(state, isA<HouseholdState>());
        expect(state.props, isEmpty);
      });

      test('HouseholdEmpty', () {
        const state = HouseholdEmpty();
        expect(state, isA<HouseholdState>());
        expect(state.props, isEmpty);
      });

      test('HouseholdLoaded', () {
        final households = [household1, household2];
        const emptyList = HouseholdLoaded(households: []);
        final nonEmpty = HouseholdLoaded(households: households);

        expect(emptyList, isA<HouseholdState>());
        expect(nonEmpty, isA<HouseholdState>());
        expect(emptyList.households, isEmpty);
        expect(nonEmpty.households, [household1, household2]);
      });

      test('HouseholdFailure', () {
        const state = HouseholdFailure(message: 'Ошибка');
        expect(state, isA<HouseholdState>());
        expect(state.message, 'Ошибка');
      });
    });

    group('HouseholdLoaded хранит список семей', () {
      test('с пустым списком', () {
        const state = HouseholdLoaded(households: []);
        expect(state.households, isEmpty);
        expect(state.props, [<Household>[]]);
      });

      test('с одной семьёй', () {
        final state = HouseholdLoaded(households: [household1]);
        expect(state.households.length, 1);
        expect(state.households.first, household1);
      });

      test('с несколькими семьями', () {
        final state = HouseholdLoaded(households: [household1, household2]);
        expect(state.households.length, 2);
        expect(state.households[0], household1);
        expect(state.households[1], household2);
      });

      test('сохраняет порядок семей', () {
        final state = HouseholdLoaded(households: [household2, household1]);
        expect(state.households[0], household2);
        expect(state.households[1], household1);
      });
    });

    group('Equatable равенство работает', () {
      test('два HouseholdInitial равны', () {
        expect(const HouseholdInitial(), const HouseholdInitial());
      });

      test('два HouseholdLoading равны', () {
        expect(const HouseholdLoading(), const HouseholdLoading());
      });

      test('два HouseholdEmpty равны', () {
        expect(const HouseholdEmpty(), const HouseholdEmpty());
      });

      test('два HouseholdLoaded с одинаковыми списками равны', () {
        final households = [household1, household2];
        final a = HouseholdLoaded(households: households);
        final b = HouseholdLoaded(households: [household1, household2]);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('два HouseholdLoaded с разными списками не равны', () {
        final a = HouseholdLoaded(households: [household1]);
        final b = HouseholdLoaded(households: [household2]);

        expect(a, isNot(b));
      });

      test('два HouseholdFailure с одинаковыми сообщениями равны', () {
        expect(
          const HouseholdFailure(message: 'Ошибка'),
          const HouseholdFailure(message: 'Ошибка'),
        );
      });

      test('два HouseholdFailure с разными сообщениями не равны', () {
        expect(
          const HouseholdFailure(message: 'Ошибка А'),
          isNot(const HouseholdFailure(message: 'Ошибка Б')),
        );
      });
    });

    group('разные состояния не равны', () {
      test('HouseholdInitial != HouseholdLoading', () {
        expect(
          const HouseholdInitial(),
          isNot(const HouseholdLoading()),
        );
      });

      test('HouseholdInitial != HouseholdEmpty', () {
        expect(
          const HouseholdInitial(),
          isNot(const HouseholdEmpty()),
        );
      });

      test('HouseholdLoading != HouseholdEmpty', () {
        expect(
          const HouseholdLoading(),
          isNot(const HouseholdEmpty()),
        );
      });

      test('HouseholdLoaded != HouseholdFailure', () {
        expect(
          const HouseholdLoaded(households: []),
          isNot(const HouseholdFailure(message: 'Ошибка')),
        );
      });

      test('HouseholdLoaded не равен другому HouseholdLoaded', () {
        final a = HouseholdLoaded(households: [household1]);
        final b = HouseholdLoaded(households: [household2]);
        expect(a, isNot(b));
      });

      test('все простые состояния разные', () {
        final states = <HouseholdState>[
          const HouseholdInitial(),
          const HouseholdLoading(),
          const HouseholdEmpty(),
          const HouseholdLoaded(households: []),
          const HouseholdFailure(message: 'Ошибка'),
        ];

        // Каждая пара различных состояний не равна
        for (var i = 0; i < states.length; i++) {
          for (var j = i + 1; j < states.length; j++) {
            expect(states[i], isNot(states[j]),
                reason: '${states[i].runtimeType} не должен быть равен '
                    '${states[j].runtimeType}');
          }
        }
      });
    });
  });
}
