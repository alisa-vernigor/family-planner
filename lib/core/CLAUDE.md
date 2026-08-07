# Core (lib/core/)

Вспомогательные сервисы и конфигурация, общие для всех фич.

## Содержимое

- **config/supabase_config.dart** — `SupabaseConfig`: читает SUPABASE_URL и SUPABASE_PUBLISHABLE_KEY из `.env` файла или `--dart-define` (compile-time). Использует `flutter_dotenv`.
- **logging/app_logger.dart** — `AppLogger`: обёртка над `logger` package (debug/info/warning/error). Статические методы, единый экземпляр `Logger()`.
- **services/home_widget_service.dart** — `HomeWidgetService`: интеграция с Android Home Widget через `home_widget` package.
  - `initialize()` — регистрация `interactiveCallback` для фоновых коллбэков.
  - `syncTasks(tasks, currentMemberId, householdId)` — обновление данных виджета.
  - Сохранение Supabase-конфигурации и сессии в SharedPreferences (через `HomeWidget.saveWidgetData`).
  - `interactiveCallback` — фоновый изолят: обрабатывает нажатие на задачу в виджете (toggle complete/uncomplete). Восстанавливает Supabase-сессию из сохранённого JSON.

## Связи

- `app_bloc_observer.dart` использует `AppLogger`.
- `main.dart` вызывает `SupabaseConfig`, `AppLogger`, `HomeWidgetService.initialize()`.
- `HomeWidgetService` импортирует `Task` из tasks feature.
- Не зависит от других модулей приложения (кроме HomeWidgetService → tasks).

## Drift-миграции (локальная БД SQLite)

`AppDatabase` (`lib/core/database/app_database.dart`) — версия `schemaVersion`, миграции через `MigrationStrategy.onUpgrade`.

Процедура изменения таблицы (например, добавления колонки):

1. Правь таблицу: `lib/core/database/tables/<table>.dart` (например, `TaskOccurrences`).
2. В `AppDatabase`: подними `schemaVersion` (например, 1 → 2) и в `MigrationStrategy.onUpgrade` добавь `migrator.addColumn(table, table.newColumn)` для каждой новой колонки (по одному вызову на колонку, по возрастанию `from`).
3. Регенерируй `.g.dart`: `dart run build_runner build` (флаг `--delete-conflicting-outputs` удалён в новых версиях — не нужен).
4. После регенерации у всех `Companion(...)` новых колонок появятся параметры — обнови их в местах создания companion (например, `DriftTaskRepository._companionFromTask`, `_upsertRemoteRows`).

Полезные команды:
- `dart run build_runner build` — регенерация.
- `dart analyze lib` — проверка после миграции.
