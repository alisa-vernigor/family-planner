import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity and exposes online/offline state.
///
/// Uses [connectivity_plus] under the hood. Caches the last known
/// state so synchronous reads are cheap.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;

  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  /// Stream that emits `true` when online, `false` when offline.
  Stream<bool> get isOnline => _onlineController.stream;

  /// Current connectivity state (cached, doesn't block).
  bool get currentOnline => _isOnline;

  void _init() {
    _connectivity.checkConnectivity().then((results) {
      _updateState(results);
    });

    _subscription = _connectivity.onConnectivityChanged.listen(_updateState);
  }

  void _updateState(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _onlineController.add(online);
    }
  }

  /// Dispose internal resources.
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
