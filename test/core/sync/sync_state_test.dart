import 'package:flutter_test/flutter_test.dart';
import 'package:family_planner/core/sync/sync_state.dart';

void main() {
  group('SyncResult', () {
    test('конструктор с параметрами по умолчанию', () {
      final result = const SyncResult();
      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.conflicts, 0);
      expect(result.isEmpty, true);
    });

    test('не пустой когда есть синхронизированные', () {
      final result = const SyncResult(synced: 3);
      expect(result.isEmpty, false);
    });

    test('toString содержит все поля', () {
      final result = const SyncResult(synced: 2, failed: 1, conflicts: 0);
      expect(result.toString(), contains('synced: 2'));
      expect(result.toString(), contains('failed: 1'));
      expect(result.toString(), contains('conflicts: 0'));
    });

    test('Equatable работает корректно', () {
      final a = const SyncResult(synced: 1, failed: 2, conflicts: 0);
      final b = const SyncResult(synced: 1, failed: 2, conflicts: 0);
      final c = const SyncResult(synced: 2, failed: 2, conflicts: 0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('SyncStatus sealed class', () {
    test('SyncSynced', () {
      const status = SyncSynced();
      expect(status, isA<SyncStatus>());
    });

    test('SyncSyncing', () {
      const status = SyncSyncing();
      expect(status, isA<SyncStatus>());
    });

    test('SyncPending содержит count', () {
      const status = SyncPending(3);
      expect(status.count, 3);
      expect(status, isA<SyncStatus>());
    });

    test('SyncError содержит message', () {
      const status = SyncError('test error');
      expect(status.message, 'test error');
      expect(status, isA<SyncStatus>());
    });
  });
}
