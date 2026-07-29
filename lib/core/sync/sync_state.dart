import 'package:equatable/equatable.dart';

/// Result of processing the sync queue.
final class SyncResult extends Equatable {
  const SyncResult({
    this.synced = 0,
    this.failed = 0,
    this.conflicts = 0,
  });

  final int synced;
  final int failed;
  final int conflicts;

  bool get isEmpty => synced == 0 && failed == 0 && conflicts == 0;

  @override
  String toString() =>
      'SyncResult(synced: $synced, failed: $failed, conflicts: $conflicts)';

  @override
  List<Object?> get props => [synced, failed, conflicts];
}

/// The overall sync status.
sealed class SyncStatus {
  const SyncStatus();
}

final class SyncSynced extends SyncStatus {
  const SyncSynced();
}

final class SyncSyncing extends SyncStatus {
  const SyncSyncing();
}

final class SyncPending extends SyncStatus {
  const SyncPending(this.count);
  final int count;
}

final class SyncError extends SyncStatus {
  const SyncError(this.message);
  final String message;
}
