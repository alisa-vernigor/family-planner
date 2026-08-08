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
- **services/reminder_service.dart** — `ReminderService`: локальные push-напоминания о задачах (`flutter_local_notifications` v22 + `timezone`).
  - Singleton: `ReminderService.instance`.
  - `initialize()` — инициализация плагина (вызывается в `main.dart`).
  - `scheduleReminder(task)` / `cancelReminder(taskId)` — планирование/отмена по `task.reminderMinutesBefore`.
  - `_isSupportedPlatform` — только Android/iOS (не web).
  - v22 API: `initialize(settings:)`, `zonedSchedule(id:, title:, body:, scheduledDate:, notificationDetails:, androidScheduleMode:)`, `cancel(id:)`.
- **database/** — Drift/SQLite (offline-first):
  - Таблицы: `TaskOccurrences` (включая nullable-колонки `category_id`, `reminder_minutes_before`, `planned_time`, **`template_active`** — кэш `task_templates.is_active` для паузы серии), `TaskTemplates`, `TaskCategories`, `TaskSubtasks`, `SyncQueue`, а также household/профильные.
  - **Важно:** row-классы `TaskCategory` / `TaskSubtask` конфликтуют с доменными сущностями tasks — в drift-репозиториях доменный импорт алиасится (`import '...task_category.dart' as domain;`).
  - DAO категорий: `TaskCategoriesDao` — метод удаления называется `deleteCategory` (избегает конфликта с базовым `DatabaseConnectionUser.delete`). Аналогично `deleteSubtask` в `TaskSubtasksDao`.

## Связи

- `app_bloc_observer.dart` использует `AppLogger`.
- `main.dart` вызывает `SupabaseConfig`, `AppLogger`, `HomeWidgetService.initialize()`, `ReminderService.instance.initialize()`.
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

### Скоростные приёмы (проверено на google-calendar-actions, 2026-08-07)

- **Читай сгенерированный `app_database.g.dart` ДО компиляции, не после.** Row-классы, семантика `copyWith` (nullable-колонки берут `Value<T>`, bool/String — plain), имена DAO-методов — всё видно в `.g.dart` заранее. Цикл «compile error → перечитать файл → фикс» съедал десятки чтений одного drift-репозитория.
- **Все Drift-правки делай батчем, build_runner — один раз в конце.** Одна регенерация — минуты; в сессии было 9 штук. Сначала все таблицы/Companion()/DAO, потом одна `dart run build_runner build`.
- **Итерация — `dart analyze <конкретный файл>` (секунды), не полный репозиторий.** Полный `dart analyze lib test` и `flutter test` — только в финале.
- **Новый виджет с `context.read<SomeRepository>()`** → сразу же проверь тесты, которые его рендерят (нужен `RepositoryProvider` в тестовом окружении). CategoryField сломал 4 теста из-за отсутствующего провайдера.
