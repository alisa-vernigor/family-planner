import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_my_households_use_case.dart';

import 'household_state.dart';

final class HouseholdCubit extends Cubit<HouseholdState> {
  HouseholdCubit({
    required this.createHouseholdUseCase,
    required this.getMyHouseholdsUseCase,
  }) : super(const HouseholdInitial());

  final CreateHouseholdUseCase createHouseholdUseCase;
  final GetMyHouseholdsUseCase getMyHouseholdsUseCase;

  Future<void> load() async {
    emit(const HouseholdLoading());

    try {
      final households = await getMyHouseholdsUseCase();

      if (households.isEmpty) {
        emit(const HouseholdEmpty());
        return;
      }

      emit(HouseholdLoaded(households: households));
    } catch (exception, stackTrace) {
      _emitFailure(exception, stackTrace);
    }
  }

  Future<void> create({required String name}) async {
    emit(const HouseholdLoading());

    try {
      final household = await createHouseholdUseCase(name: name);

      AppLogger.info('Создана семья: householdId=${household.id}');

      emit(HouseholdLoaded(households: [household]));
    } catch (exception, stackTrace) {
      _emitFailure(exception, stackTrace);
    }
  }

  void _emitFailure(Object exception, StackTrace stackTrace) {
    const message = 'Не удалось загрузить или создать семью.';

    AppLogger.error(message, error: exception, stackTrace: stackTrace);

    emit(const HouseholdFailure(message: message));
  }
}
