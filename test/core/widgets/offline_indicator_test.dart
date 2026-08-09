import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/core/sync/sync_state.dart';
import 'package:family_planner/core/widgets/offline_indicator.dart';

class _MockConnectivity extends Mock implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => checkResult;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  List<ConnectivityResult> checkResult = [ConnectivityResult.wifi];
}

void main() {
  late _MockConnectivity fakeConnectivity;
  late ConnectivityService connectivity;
  late SyncCubit cubit;

  setUp(() {
    fakeConnectivity = _MockConnectivity();
    connectivity = ConnectivityService(connectivity: fakeConnectivity);
    cubit = SyncCubit(connectivityService: connectivity);
  });

  tearDown(() {
    connectivity.dispose();
    cubit.close();
  });

  Widget wrap() {
    return BlocProvider<SyncCubit>.value(
      value: cubit,
      child: MaterialApp(
        home: Scaffold(
          body: OfflineIndicator(),
        ),
      ),
    );
  }

  testWidgets('онлайн + SyncSynced → ничего не показывает', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.textContaining('Нет подключения'), findsNothing);
    expect(find.text('Синхронизация...'), findsNothing);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('офлайн с самого начала → показывает баннер', (tester) async {
    // Офлайн с рождения сервиса: checkConnectivity() вернёт none
    // синхронно в конструкторе, состояние установится сразу.
    fakeConnectivity.checkResult = [ConnectivityResult.none];
    connectivity = ConnectivityService(connectivity: fakeConnectivity);
    cubit = SyncCubit(connectivityService: connectivity);

    await tester.pumpWidget(wrap());

    expect(find.textContaining('Нет подключения'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Ок'), findsOneWidget);
  });

  testWidgets('кнопка Ок показывает SnackBar', (tester) async {
    fakeConnectivity.checkResult = [ConnectivityResult.none];
    connectivity = ConnectivityService(connectivity: fakeConnectivity);
    cubit = SyncCubit(connectivityService: connectivity);

    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Ок'));
    await tester.pump();

    expect(
      find.text('Изменения будут синхронизированы при подключении к интернету.'),
      findsOneWidget,
    );
  });

  testWidgets('онлайн + SyncSyncing → показывает синхронизацию', (tester) async {
    await tester.pumpWidget(wrap());

    cubit.onSyncStarted();
    await tester.pump();

    expect(find.text('Синхронизация...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('онлайн + SyncError → сообщение ошибки', (tester) async {
    await tester.pumpWidget(wrap());

    cubit.onSyncCompleted(const SyncResult(failed: 2));
    await tester.pump();

    expect(find.textContaining('Ошибка синхронизации: 2'), findsOneWidget);
  });

  testWidgets('офлайн + syncing → облако без спиннера', (tester) async {
    fakeConnectivity.checkResult = [ConnectivityResult.none];
    connectivity = ConnectivityService(connectivity: fakeConnectivity);
    cubit = SyncCubit(connectivityService: connectivity);

    await tester.pumpWidget(wrap());
    cubit.onSyncStarted();
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('онлайн + SyncPending → показывает число операций', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    cubit.emit(
      cubit.state.copyWith(
        status: const SyncPending(3),
        pendingCount: 3,
      ),
    );
    await tester.pump();

    expect(find.text('Ожидает синхронизации: 3 операций'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('офлайн → sync завершился без ошибок → баннер исчезает',
      (tester) async {
    fakeConnectivity.checkResult = [ConnectivityResult.none];
    connectivity = ConnectivityService(connectivity: fakeConnectivity);
    cubit = SyncCubit(connectivityService: connectivity);

    await tester.pumpWidget(wrap());
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    // Статус онлайн приходит от сервиса — эмитим wifi и ждём.
    fakeConnectivity.emit([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
