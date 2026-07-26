import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/delete_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_my_households_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/update_household_use_case.dart';

import 'household_state.dart';

final class HouseholdCubit extends Cubit<HouseholdState> {
  HouseholdCubit({
    required this.createHouseholdUseCase,
    required this.getMyHouseholdsUseCase,
    required this.deleteHouseholdUseCase,
    required this.updateHouseholdUseCase,
  }) : super(const HouseholdInitial());

  final CreateHouseholdUseCase createHouseholdUseCase;
  final GetMyHouseholdsUseCase getMyHouseholdsUseCase;
  final DeleteHouseholdUseCase deleteHouseholdUseCase;
  final UpdateHouseholdUseCase updateHouseholdUseCase;

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
      await createHouseholdUseCase(name: name);

      AppLogger.info('Создана семья');

      await load();
    } catch (exception, stackTrace) {
      _emitFailure(exception, stackTrace);
    }
  }

  Future<void> delete({required String householdId}) async {
    emit(const HouseholdLoading());

    try {
      await deleteHouseholdUseCase(householdId: householdId);

      AppLogger.info('Семья удалена: householdId=$householdId');

      await load();
    } catch (exception, stackTrace) {
      const message = 'Не удалось удалить семью.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const HouseholdFailure(message: message));
    }
  }

  Future<void> update({
    required String householdId,
    required String name,
  }) async {
    try {
      await updateHouseholdUseCase(householdId: householdId, name: name);

      AppLogger.info('Семья переименована: householdId=$householdId');

      await load();
    } catch (exception, stackTrace) {
      const message = 'Не удалось переименовать семью.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const HouseholdFailure(message: message));
    }
  }

  void _emitFailure(Object exception, StackTrace stackTrace) {
    const message = 'Не удалось загрузить или создать семью.';

    AppLogger.error(message, error: exception, stackTrace: stackTrace);

    emit(const HouseholdFailure(message: message));
  }
}
