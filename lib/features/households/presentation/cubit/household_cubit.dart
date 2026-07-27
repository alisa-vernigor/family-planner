import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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

  /// Полная загрузка — показывает спиннер (для первого входа / ошибки).
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
      const message = 'Не удалось загрузить или создать семью.';

      AppLogger.error(message, error: exception, stackTrace: stackTrace);

      emit(const HouseholdFailure(message: message));
    }
  }

  /// Тихая перезагрузка — не показывает спиннер, если данные уже есть.
  Future<void> refresh() async {
    final previousState = state;

    await _fetchHouseholds(
      onFailure: () {
        if (previousState case HouseholdLoaded()) {
          emit(previousState);
        } else {
          emit(const HouseholdFailure(
            message: 'Не удалось загрузить или создать семью.',
          ));
        }
      },
    );
  }

  Future<void> _fetchHouseholds({
    required void Function() onFailure,
  }) async {
    try {
      final households = await getMyHouseholdsUseCase();

      if (households.isEmpty) {
        emit(const HouseholdEmpty());
        return;
      }

      emit(HouseholdLoaded(households: households));
    } catch (exception, stackTrace) {
      AppLogger.error(
        'Не удалось загрузить или создать семью.',
        error: exception,
        stackTrace: stackTrace,
      );

      onFailure();
    }
  }

  Future<void> create({required String name}) async {
    emit(const HouseholdLoading());

    try {
      await createHouseholdUseCase(name: name);

      AppLogger.info('Создана семья');

      await load();
    } catch (exception, stackTrace) {
      _emitFailure(exception, stackTrace, 'Не удалось создать семью.');
    }
  }

  Future<void> delete({required String householdId}) async {
    final previousState = state;

    try {
      await deleteHouseholdUseCase(householdId: householdId);

      AppLogger.info('Семья удалена: householdId=$householdId');

      await load();
    } catch (exception, stackTrace) {
      // Возвращаем предыдущее состояние при ошибке
      if (previousState case HouseholdLoaded()) {
        emit(previousState);
      }
      _emitFailure(exception, stackTrace, 'Не удалось удалить семью.');
    }
  }

  Future<void> update({
    required String householdId,
    required String name,
  }) async {
    try {
      await updateHouseholdUseCase(householdId: householdId, name: name);

      AppLogger.info('Семья переименована: householdId=$householdId');

      await refresh();
    } catch (exception, stackTrace) {
      _emitFailure(exception, stackTrace, 'Не удалось переименовать семью.');
    }
  }

  void _emitFailure(
    Object exception,
    StackTrace stackTrace,
    String message,
  ) {
    final detail = _postgrestMessage(exception);
    final fullMessage = detail != null ? '$message $detail' : message;

    AppLogger.error(fullMessage, error: exception, stackTrace: stackTrace);

    emit(HouseholdFailure(message: fullMessage));
  }
}

/// Вытаскивает человекочитаемую причину из PostgrestException.
String? _postgrestMessage(Object error) {
  if (error is! PostgrestException) return null;

  final msg = error.message;
  if (msg == null || msg.isEmpty) return null;

  if (msg.contains('row-level security') || msg.contains('violates policy')) {
    return 'Недостаточно прав. Только владелец может выполнить это действие.';
  }

  if (msg.contains('duplicate key') || msg.contains('already exists')) {
    return 'Такая запись уже существует.';
  }

  return msg;
}
