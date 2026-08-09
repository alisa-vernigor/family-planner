# Import/Export (lib/features/import_export/)

Импорт/экспорт задач семьи в JSON. Формат дружелюбный к нейросетям — пользователь может сгенерить задачи по дому нейросетью и загрузить их в приложение (и выгрузить существующие).

**JSON Schema для нейросети лежит в `docs/import_schema.json`** — при генерации/импорте дай её модели, чтобы формат совпадал.

## JSON-формат

```json
{
  "version": 1,
  "tasks": [
    {
      "title": "Помыть посуду",
      "description": "…",
      "date": "2026-08-09",            // опц. Без даты → сегодня
      "time": "18:00",                  // опц. время начала
      "deadline": "2026-08-09T20:00",   // опц.
      "duration_minutes": 30,           // опц. дефолт 30 (0/≤0 → 30, зажим до 1440)
      "priority": 2,                    // опц. 1–4 (Эйзенхауэр) или high/medium/low/none
      "assignee": "Мама",               // опц. по displayName участника
      "category": "Кухня",              // опц. по имени категории (создаётся при отсутствии)
      "subtasks": ["Мыло", "Губка"]     // опц.
    }
  ]
}
```

- **Экспорт без внутренних id**: `assignee`/`category` — по именам, чтобы файл можно было переимпортировать в другую семью/аккаунт.
- **Импорт**: категория по имени создаётся, если её нет в семье; исполнитель по имени (не найден → без исполнителя); задача без `date` → сегодня.

## Содержимое

### domain/entities/

- **task_transfer_file.dart** — `TaskTransferItem` (title, description?, date?, time? (Duration, минуты от полуночи), deadline?, durationMinutes (default 30), priority? (EisenhowerPriority), assignee?, category?, subtasks[]) + `TaskTransferFile` (version, tasks). Ручная (де)сериализация (без кодогена). `toJsonString()` — pretty JSON.
- **task_import_result.dart** — `TaskImportResult { imported, skipped, errors[] }`, `copyWith`, `hasErrors`.

### domain/use_cases/

- **task_import_use_case.dart** — `TaskImportUseCase`:
  - Конструктор: `taskRepository`, `taskCategoryRepository`, `taskSubtaskRepository`, `householdRepository`, `isOnline` (`bool Function()`).
  - `import(jsonString, householdId)` → `TaskImportResult`. Каждая задача импортируется независимо (ошибка одной не ломает остальные).
  - Валидация через `validateCreateTaskParams` (вынесена из `CreateTaskUseCase` — см. tasks feature).
  - Создание категорий по имени (при отсутствии) через `TaskCategoryRepository.create`.
  - Подзадачи привязываются к серверному id задачи (`task.id`).
  - **Только онлайн**: без сети бросает `TaskImportOfflineException` (см. «Ограничения»).
  - Исключения: `TaskImportOfflineException`, `TaskImportFormatException`.
- **task_export_use_case.dart** — `TaskExportUseCase.export(householdId)` → JSON-строка. Берёт `getAllPending` (невыполненные, как в «Запланированных»), маппит id → имена (участники через `HouseholdRepository.getMembers`, категории через `TaskCategoryRepository.getForHousehold`), подзадачи через `TaskSubtaskRepository.getForTask`.

### data/

- **task_file_service.dart** — `TaskFileService` (статические методы):
  - `readClipboard()` / `writeClipboard(String)` — системный буфер через `Clipboard`.
  - `pickJsonFile()` — выбор `.json` через `FilePicker` (v11: **статические** `FilePicker.pickFiles`, не `FilePicker.platform.*`). `withData` не поддерживается на macOS — читаем по `path`, fallback на `bytes`.
  - `saveJsonFile(content, {suggestedName})` — `FilePicker.saveFile`. На web (`kIsWeb`) обе функции пикеров возвращают `null`/`false`.
  - **Тестовый шов:** `@visibleForTesting static JsonFileWriter writeJsonFile` — замена `File.writeAsString`. Реальный `dart:io` в FakeAsync-зоне `testWidgets` не завершается, поэтому виджет-тест экспорта в файл подменяет `writeJsonFile` на in-memory запись.

### presentation/pages/

- **import_export_page.dart** — `ImportExportPage(householdId, onImported?)`:
  - Кнопки: «Импортировать из буфера», «Импортировать из файла» (скрыта на web), «Экспортировать в буфер», «Экспортировать в файл» (скрыта на web).
  - Читает репозитории через `context.read` и конструирует use case'ы на месте.
  - После импорта вызывает `onImported` (AppShell пересоздаёт табы).
  - **Гварды «доступно только в мобильном приложении» внутри `_importFromFile`/`_exportToFile` удалены** — кнопки файлов скрыты при `kIsWeb`, поэтому обработчики на web недостижимы (были мёртвым кодом).

## UI-вход

Пункт «Импорт / экспорт задач» в меню «Ещё» (`PopupMenuButton` в `app_shell.dart`, `value: 'import_export'`) → `MaterialPageRoute` на `ImportExportPage` с текущим `selectedHouseholdId`.

## Обновление после импорта

`ImportExportPage.onImported` → `AppShell._onImported()` инкрементирует `_dataVersion`, который добавлен в `ValueKey` табов Today/Scheduled (`'today_${household}_${_dataVersion}'`). Это полностью пересоздаёт страницы — списки задач и **карту категорий** (`_categoriesById`), которые иначе загружаются только в `initState`.

## Ограничения (важно)

- **Подзадачи при импорте — только онлайн.** `create_task_occurrence` RPC генерит id задачи на сервере (нет id-mapping), а `SUBTASK_CREATE` требует серверный `task_occurrence_id`. Поэтому импорт работает напрямую через `repository.create` (онлайн → настоящий id) и создаёт подзадачи по нему. Офлайн → `TaskImportOfflineException` (вместо надежды на sync-очередь).
- Экспорт не включает выполненные задачи (`getAllPending`).
- При импорте в другую семью категории создадутся заново (по имени); исполнитель не найдётся → задача без исполнителя.

## Связи

- Зависит от `tasks` (TaskRepository, TaskCategoryRepository, TaskSubtaskRepository, CreateTaskParams/validateCreateTaskParams, Task), `households` (HouseholdRepository, HouseholdMember), `core` (AppLogger, ConnectivityService).
- Не добавляет RPC/миграций/таблиц — только клиентский код + `file_picker` зависимость.
