import 'package:equatable/equatable.dart';

/// Результат импорта задач из JSON.
final class TaskImportResult extends Equatable {
  const TaskImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;

  TaskImportResult copyWith({
    int? imported,
    int? skipped,
    List<String>? errors,
  }) {
    return TaskImportResult(
      imported: imported ?? this.imported,
      skipped: skipped ?? this.skipped,
      errors: errors ?? this.errors,
    );
  }

  @override
  List<Object?> get props => [imported, skipped, errors];
}
