/// Import/export feature — public API.
///
/// Импорт/экспорт задач семьи в JSON (формат дружелюбный к нейросетям).
///
/// - [TaskTransferFile] / [TaskTransferItem] — доменные модели формата.
/// - [TaskImportUseCase] — импорт JSON в семью (только онлайн).
/// - [TaskExportUseCase] — экспорт невыполненных задач в JSON.
/// - [ImportExportPage] — UI (вход из меню «Ещё» в AppShell).
library;

export 'domain/entities/task_transfer_file.dart';
export 'domain/entities/task_import_result.dart';
export 'domain/use_cases/task_import_use_case.dart';
export 'domain/use_cases/task_export_use_case.dart';

export 'presentation/pages/import_export_page.dart';
