import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/core/logging/app_logger.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/import_export/data/task_file_service.dart';
import 'package:family_planner/features/import_export/domain/entities/task_import_result.dart';
import 'package:family_planner/features/import_export/domain/use_cases/task_export_use_case.dart';
import 'package:family_planner/features/import_export/domain/use_cases/task_import_use_case.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';

/// Экран импорта/экспорта задач (JSON).
///
/// Позволяет:
/// - импортировать задачи из буфера обмена или `.json`-файла;
/// - экспортировать невыполненные задачи в буфер или в файл.
///
/// После успешного импорта вызывает [onImported] — AppShell использует его,
/// чтобы перезагрузить экраны Today/Scheduled.
final class ImportExportPage extends StatelessWidget {
  const ImportExportPage({
    required this.householdId,
    this.onImported,
    super.key,
  });

  final String householdId;
  final VoidCallback? onImported;

  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final categoryRepository = context.read<TaskCategoryRepository>();
    final subtaskRepository = context.read<TaskSubtaskRepository>();
    final householdRepository = context.read<HouseholdRepository>();
    final connectivity = context.read<ConnectivityService>();

    final importUseCase = TaskImportUseCase(
      taskRepository: taskRepository,
      taskCategoryRepository: categoryRepository,
      taskSubtaskRepository: subtaskRepository,
      householdRepository: householdRepository,
      isOnline: () => connectivity.currentOnline,
    );
    final exportUseCase = TaskExportUseCase(
      taskRepository: taskRepository,
      taskCategoryRepository: categoryRepository,
      taskSubtaskRepository: subtaskRepository,
      householdRepository: householdRepository,
    );

    return _ImportExportView(
      householdId: householdId,
      importUseCase: importUseCase,
      exportUseCase: exportUseCase,
      onImported: onImported,
    );
  }
}

final class _ImportExportView extends StatefulWidget {
  const _ImportExportView({
    required this.householdId,
    required this.importUseCase,
    required this.exportUseCase,
    this.onImported,
  });

  final String householdId;
  final TaskImportUseCase importUseCase;
  final TaskExportUseCase exportUseCase;
  final VoidCallback? onImported;

  @override
  State<_ImportExportView> createState() => _ImportExportViewState();
}

final class _ImportExportViewState extends State<_ImportExportView> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importFromClipboard() async {
    await _run(() async {
      final text = await TaskFileService.readClipboard();
      if (text == null || text.trim().isEmpty) {
        _showSnack('В буфере обмена нет текста.');
        return;
      }
      await _importJson(text);
    });
  }

  Future<void> _importFromFile() async {
    await _run(() async {
      final content = await TaskFileService.pickJsonFile();
      if (content == null || content.trim().isEmpty) {
        _showSnack('Файл пуст или выбор отменён.');
        return;
      }
      await _importJson(content);
    });
  }

  Future<void> _importJson(String jsonString) async {
    try {
      final result = await widget.importUseCase.import(
        jsonString: jsonString,
        householdId: widget.householdId,
      );
      _showResult(result);
      if (result.imported > 0) {
        widget.onImported?.call();
      }
    } on TaskImportOfflineException catch (e) {
      _showSnack('$e');
    } on TaskImportFormatException catch (e) {
      _showSnack('$e');
    } catch (e, st) {
      AppLogger.error('Импорт не удался', error: e, stackTrace: st);
      _showSnack('Не удалось импортировать задачи.');
    }
  }

  void _showResult(TaskImportResult result) {
    if (result.imported == 0 && result.errors.isEmpty) {
      _showSnack('В файле нет задач.');
      return;
    }

    final base = 'Импортировано: ${result.imported}'
        '${result.skipped > 0 ? ', пропущено: ${result.skipped}' : ''}';
    if (result.errors.isEmpty) {
      _showSnack(base);
      return;
    }

    final preview = result.errors.take(3).join('\n');
    final more = result.errors.length > 3
        ? '\n… и ещё ${result.errors.length - 3}'
        : '';
    _showSnack('$base\n$preview$more');
  }

  Future<void> _exportToClipboard() async {
    await _run(() async {
      final json = await widget.exportUseCase.export(
        householdId: widget.householdId,
      );
      final ok = await TaskFileService.writeClipboard(json);
      if (ok) {
        _showSnack('JSON скопирован в буфер обмена.');
      } else {
        _showSnack('Не удалось скопировать в буфер.');
      }
    });
  }

  Future<void> _exportToFile() async {
    await _run(() async {
      final json = await widget.exportUseCase.export(
        householdId: widget.householdId,
      );
      final ok = await TaskFileService.saveJsonFile(json);
      if (ok) {
        _showSnack('Задачи сохранены в файл.');
      } else {
        _showSnack('Сохранение отменено или не удалось.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт / экспорт задач')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'JSON-формат позволяет переносить задачи между семьями. '
              'Задачи без даты будут созданы на сегодня.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Импорт'),
            _ActionTile(
              icon: Icons.content_paste_go_outlined,
              title: 'Импортировать из буфера',
              subtitle: 'Вставить JSON, сгенерированный нейросетью',
              onTap: _busy ? null : _importFromClipboard,
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.file_open_outlined,
                title: 'Импортировать из файла',
                subtitle: 'Выбрать .json файл',
                onTap: _busy ? null : _importFromFile,
              ),
            ],
            const SizedBox(height: 24),
            _SectionTitle('Экспорт'),
            _ActionTile(
              icon: Icons.copy_all_outlined,
              title: 'Экспортировать в буфер',
              subtitle: 'Скопировать JSON всех невыполненных задач',
              onTap: _busy ? null : _exportToClipboard,
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.save_alt_outlined,
                title: 'Экспортировать в файл',
                subtitle: 'Сохранить .json файл',
                onTap: _busy ? null : _exportToFile,
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

final class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      enabled: onTap != null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
