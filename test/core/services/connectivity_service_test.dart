import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/core/services/connectivity_service.dart';

/// Мок [Connectivity] с управляемым stream.
class _MockConnectivity extends Mock implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  void addError(Object error) => _controller.addError(error);

  void closeStream() => _controller.close();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => checkResult;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  List<ConnectivityResult> checkResult = [ConnectivityResult.wifi];
}

void main() {
  late _MockConnectivity fakeConnectivity;
  late ConnectivityService service;

  setUp(() {
    fakeConnectivity = _MockConnectivity();
    service = ConnectivityService(connectivity: fakeConnectivity);
  });

  tearDown(() {
    service.dispose();
  });

  test('стартует онлайн при наличии связи', () async {
    await Future<void>.delayed(Duration.zero);
    expect(service.currentOnline, isTrue);
  });

  test('currentOnline false когда нет связи', () async {
    fakeConnectivity.checkResult = [ConnectivityResult.none];
    service = ConnectivityService(connectivity: fakeConnectivity);
    await Future<void>.delayed(Duration.zero);

    expect(service.currentOnline, isFalse);
  });

  test('переход в офлайн эмитит false в поток', () async {
    await Future<void>.delayed(Duration.zero);
    expect(service.currentOnline, isTrue);

    final values = <bool>[];
    final sub = service.isOnline.listen(values.add);

    fakeConnectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);

    expect(values, [false]);
    expect(service.currentOnline, isFalse);

    await sub.cancel();
  });

  test('повторный выброс того же состояния не эмитит', () async {
    await Future<void>.delayed(Duration.zero);

    final values = <bool>[];
    final sub = service.isOnline.listen(values.add);

    fakeConnectivity.emit([ConnectivityResult.wifi]); // уже онлайн
    await Future<void>.delayed(Duration.zero);

    expect(values, isEmpty);

    await sub.cancel();
  });

  test('переход обратно в онлайн эмитит true', () async {
    await Future<void>.delayed(Duration.zero);

    final values = <bool>[];
    final sub = service.isOnline.listen(values.add);

    fakeConnectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    fakeConnectivity.emit([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);

    expect(values, [false, true]);

    await sub.cancel();
  });

  test('ошибка в потоке платформы не роняет сервис', () async {
    await Future<void>.delayed(Duration.zero);
    expect(service.currentOnline, isTrue);

    // Добавляем ошибку в поток — onError не должен бросать исключение.
    fakeConnectivity.addError(Exception('channel closed'));
    await Future<void>.delayed(Duration.zero);

    expect(service.currentOnline, isTrue);
  });
}
