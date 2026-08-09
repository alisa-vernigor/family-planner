import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/core/sync/sync_state.dart';

class _MockConnectivityService extends Mock implements ConnectivityService {
  final _onlineController = StreamController<bool>.broadcast();

  @override
  bool currentOnline = true;

  @override
  Stream<bool> get isOnline => _onlineController.stream;
}

void main() {
  late _MockConnectivityService connectivity;
  late SyncCubit cubit;

  setUp(() {
    connectivity = _MockConnectivityService();
    cubit = SyncCubit(connectivityService: connectivity);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('SyncCubit', () {
    test('начальное состояние онлайн + SyncSynced', () {
      expect(cubit.state.isOnline, isTrue);
      expect(cubit.state.status, isA<SyncSynced>());
      expect(cubit.state.pendingCount, 0);
    });

    test('инициализирует isOnline из сервиса', () {
      connectivity.currentOnline = false;
      final offlineCubit = SyncCubit(connectivityService: connectivity);
      expect(offlineCubit.state.isOnline, isFalse);
      offlineCubit.close();
    });

    test('подписывается на isOnline и меняет состояние', () async {
      final values = <bool>[];
      final sub = cubit.stream.listen((s) => values.add(s.isOnline));

      connectivity._onlineController.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isOnline, isFalse);
      await sub.cancel();
    });

    test('onSyncStarted ставит SyncSyncing', () {
      cubit.onSyncStarted();

      expect(cubit.state.status, isA<SyncSyncing>());
    });

    test('onSyncCompleted без ошибок ставит SyncSynced', () {
      cubit.onSyncStarted();
      cubit.onSyncCompleted(const SyncResult(synced: 3, failed: 0));

      expect(cubit.state.status, isA<SyncSynced>());
    });

    test('onSyncCompleted с ошибками ставит SyncError', () {
      cubit.onSyncCompleted(const SyncResult(synced: 1, failed: 2));

      expect(cubit.state.status, isA<SyncError>());
      expect((cubit.state.status as SyncError).message, contains('2'));
    });

    test('onSyncError ставит SyncError с сообщением', () {
      cubit.onSyncError('Сеть недоступна');

      expect(cubit.state.status, isA<SyncError>());
      expect((cubit.state.status as SyncError).message, 'Сеть недоступна');
    });

    test('после close() не эмитит новые состояния', () async {
      await cubit.close();
      final status = cubit.state.status;

      cubit.onSyncStarted();
      cubit.onSyncError('x');
      cubit.onSyncCompleted(const SyncResult(failed: 1));

      expect(cubit.state.status, status);
    });
  });
}
