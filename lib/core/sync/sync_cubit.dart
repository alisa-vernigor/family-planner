import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:family_planner/core/services/connectivity_service.dart';

import 'sync_state.dart';

final class SyncCubitState extends Equatable {
  const SyncCubitState({
    this.isOnline = true,
    this.status = const SyncSynced(),
    this.pendingCount = 0,
  });

  final bool isOnline;
  final SyncStatus status;
  final int pendingCount;

  @override
  List<Object?> get props => [isOnline, status, pendingCount];
}

final class SyncCubit extends Cubit<SyncCubitState> {
  SyncCubit({
    required ConnectivityService connectivityService,
  })  : _connectivityService = connectivityService,
        super(const SyncCubitState()) {
    _setupListeners();
  }

  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _onlineSubscription;
  bool _disposed = false;

  void _setupListeners() {
    emit(state.copyWith(isOnline: _connectivityService.currentOnline));

    _onlineSubscription = _connectivityService.isOnline.listen((online) {
      if (_disposed) return;
      emit(state.copyWith(isOnline: online));
    });
  }

  void onSyncStarted() {
    if (_disposed) return;
    emit(state.copyWith(status: const SyncSyncing()));
  }

  void onSyncCompleted(SyncResult result) {
    if (_disposed) return;
    if (result.failed > 0) {
      emit(state.copyWith(
        status: SyncError('Ошибка синхронизации: ${result.failed} операций'),
      ));
    } else {
      emit(state.copyWith(status: const SyncSynced()));
    }
  }

  void onSyncError(String message) {
    if (_disposed) return;
    emit(state.copyWith(status: SyncError(message)));
  }

  @override
  Future<void> close() async {
    _disposed = true;
    await _onlineSubscription?.cancel();
    super.close();
  }
}

extension SyncCubitStateCopy on SyncCubitState {
  SyncCubitState copyWith({
    bool? isOnline,
    SyncStatus? status,
    int? pendingCount,
  }) {
    return SyncCubitState(
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}
