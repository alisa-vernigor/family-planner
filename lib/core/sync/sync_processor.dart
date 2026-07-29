import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/database/daos/sync_queue_dao.dart';
import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';

import 'sync_state.dart';

/// Processes the persistent mutation queue against Supabase.
///
/// Queue entries are replayed in FIFO order when connectivity is available.
/// Failed entries are retried up to [maxRetries] times before being dropped.
class SyncProcessor {
  SyncProcessor({
    required SyncQueueDao queueDao,
    required SupabaseClient supabaseClient,
    required ConnectivityService connectivityService,
  })  : _queueDao = queueDao,
        _supabase = supabaseClient,
        _connectivity = connectivityService;

  final SyncQueueDao _queueDao;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;

  bool _isProcessing = false;

  /// Whether a sync cycle is currently running.
  bool get isProcessing => _isProcessing;

  /// Max retries before dropping a queue entry.
  static const int maxRetries = 5;

  final StreamController<SyncProcessorEvent> _eventController =
      StreamController<SyncProcessorEvent>.broadcast();

  Stream<SyncProcessorEvent> get events => _eventController.stream;

  /// Process all pending queue entries against Supabase.
  Future<SyncResult> processPending() async {
    if (!_connectivity.currentOnline) {
      throw const SyncOfflineException();
    }

    if (_isProcessing) return const SyncResult();

    _isProcessing = true;
    _eventController.add(const SyncProcessorEvent.processing());

    try {
      final entries = await _queueDao.getPending();
      if (entries.isEmpty) {
        _eventController.add(const SyncProcessorEvent.idle());
        return const SyncResult();
      }

      var synced = 0;
      var failed = 0;
      var conflicts = 0;

      for (final entry in entries) {
        try {
          await _processEntry(entry);
          await _queueDao.deleteProcessed(entry.id);
          synced++;
        } on SyncConflictException catch (e) {
          conflicts++;
          AppLogger.warning('Sync conflict: ${e.message}');
          // Server wins for LWW — drop local entry.
          await _queueDao.deleteProcessed(entry.id);
        } catch (e) {
          failed++;
          await _queueDao.markFailed(entry.id, e.toString());

          if (entry.retryCount + 1 >= maxRetries) {
            AppLogger.error(
              'Sync entry exceeded max retries, dropping: '
              'id=${entry.id}, operation=${entry.operation}',
              error: e,
            );
            await _queueDao.deleteProcessed(entry.id);
          }
        }
      }

      final result = SyncResult(
        synced: synced,
        failed: failed,
        conflicts: conflicts,
      );

      _eventController.add(const SyncProcessorEvent.idle());
      return result;
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processEntry(SyncQueueData entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

    switch (entry.operation) {
      case 'CREATE':
        await _supabase.rpc('create_task_occurrence', params: payload);
      case 'UPDATE':
        await _supabase
            .from('task_occurrences')
            .update(payload)
            .eq('id', entry.entityId);
      case 'DELETE':
        await _supabase
            .from('task_occurrences')
            .delete()
            .eq('id', entry.entityId);
      case 'PATCH_STATUS':
        await _supabase
            .from('task_occurrences')
            .update(payload)
            .eq('id', entry.entityId);
      case 'ADD_ALLOWED':
        await _supabase
            .from('task_occurrence_allowed_members')
            .insert(payload);
      case 'REMOVE_ALLOWED':
        await _supabase
            .from('task_occurrence_allowed_members')
            .delete()
            .eq('task_occurrence_id', payload['task_occurrence_id'])
            .eq('profile_id', payload['profile_id']);
      default:
        AppLogger.warning('Unknown sync operation: ${entry.operation}');
    }
  }

  /// Dispose internal resources.
  void dispose() {
    _eventController.close();
  }
}

// ── Events ──────────────────────────────────────────────────

sealed class SyncProcessorEvent {
  const SyncProcessorEvent();
  const factory SyncProcessorEvent.processing() = _Processing;
  const factory SyncProcessorEvent.idle() = _Idle;
}

final class _Processing extends SyncProcessorEvent {
  const _Processing();
}

final class _Idle extends SyncProcessorEvent {
  const _Idle();
}

// ── Exceptions ──────────────────────────────────────────────

final class SyncOfflineException implements Exception {
  const SyncOfflineException();

  @override
  String toString() => 'SyncOfflineException: нет подключения к интернету.';
}

final class SyncConflictException implements Exception {
  const SyncConflictException(this.message);
  final String message;

  @override
  String toString() => 'SyncConflictException: $message';
}
