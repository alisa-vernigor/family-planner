# Core (lib/core/)

Вспомогательные сервисы и конфигурация, общие для всех фич.

## Содержимое

- **config/supabase_config.dart** — `SupabaseConfig`: читает SUPABASE_URL и SUPABASE_PUBLISHABLE_KEY из `.env` файла или `--dart-define` (compile-time). Использует `flutter_dotenv`. Проверяет `dotenv.isInitialized` перед чтением (иначе в тестах без dotenv падает).
- **services/connectivity_service.dart** — `ConnectivityService`: мониторит связь (online/offline), кэширует состояние, поток `isOnline`.
  - **DI:** конструктор принимает `Connectivity?` (пакет `connectivity_plus` — синглтон, хардкодит платформу при первом обращении). Для тестов передавай `Mock implements Connectivity` с управляемым stream. См. `test/core/services/connectivity_service_test.dart`.
- **widgets/offline_indicator.dart** — `OfflineIndicator`: баннер офлайна/синхронизации на основе `SyncCubit`.
  - **Не использует `MaterialBanner`** (тот требует непустой `actions`, падал при online+syncing с пустым actions) — рисует собственный `Container`+`Row`. Не менять обратно.
- **mixins/realtime_tasks_subscription.dart** — `RealtimeTasksSubscriptionMixin`: подписка на realtime-изменения `task_occurrences` для `State`-виджетов (Today, Scheduled). Debounce 1.5с перед `onChanged`.
  - **ВАЖНО:** проверка «инициализирован ли Supabase» — через try/catch вокруг `Supabase.instance.isInitialized`, потому что сам геттер `Supabase.instance` в debug бросает AssertionError, если экземпляр не инициализирован (assert внутри геттера). Раньше guard `if (!Supabase.instance.isInitialized) return;` сам падал в тестах/без бэкенда.
  - `reattachTaskSubscription` — пересоздание канала при смене household; `unsubscribeFromTaskChanges` — отписка.
- **services/home_widget_service.dart** — `HomeWidgetService`: интеграция с Android Home Widget через `home_widget` package.
  - `initialize({bool Function()? isSupportedPlatform})` — регистрация `interactiveCallback` для фоновых коллбэков. Параметр позволяет тестам на хосте (macOS) пройти платформенный guard.
  - `syncTasks(tasks, currentMemberId, householdId, {bool Function()? isSupportedPlatform})` — обновление данных виджета.
  - Сохранение Supabase-конфигурации и сессии в SharedPreferences (через `HomeWidget.saveWidgetData`).
  - Подписка на `onAuthStateChange` — обязательно с `onError`: ошибка стрима (например, сбой `recoverSession` в фоновом коллбэке) без него роняет приложение (в `gotrue` она прилетает как ошибка стрима, а не исключение).
  - `interactiveCallback` — фоновый изолят: обрабатывает нажатие на задачу в виджете (toggle complete/uncomplete). Восстанавливает Supabase-сессию из сохранённого JSON.
  - Платформенный guard вынесен в глобальную `defaultSupportedPlatform()` (Android/iOS; web — false) — тесты переопределяют через параметр.
- **services/reminder_service.dart** — `ReminderService`: локальные push-напоминания о задачах (`flutter_local_notifications` v22 + `timezone`).
  - Singleton: `ReminderService.instance`. Для тестов: `ReminderService.forTesting(plugin: ...)` — подмена плагина.
  - `initialize({bool Function()? isSupportedPlatform})` — инициализация плагина (вызывается в `main.dart`). Параметр переопределяет платформенный guard для тестов на хосте.
  - `scheduleReminder(task)` / `cancelReminder(taskId)` — планирование/отмена по `task.reminderMinutesBefore`.
  - v22 API: `initialize(settings:)`, `zonedSchedule(id:, title:, body:, scheduledDate:, notificationDetails:, androidScheduleMode:)`, `cancel(id:)`.
- **database/** — Drift/SQLite (offline-first):
  - Таблицы: `TaskOccurrences` (включая nullable-колонки `category_id`, `reminder_minutes_before`, `planned_time`, **`template_active`** — кэш `task_templates.is_active` для паузы серии), `TaskTemplates`, `TaskCategories`, `TaskSubtasks`, `SyncQueue`, а также household/профильные.
  - **Важно:** row-классы `TaskCategory` / `TaskSubtask` конфликтуют с доменными сущностями tasks — в drift-репозиториях доменный импорт алиасится (`import '...task_category.dart' as domain;`).
  - DAO категорий: `TaskCategoriesDao` — метод удаления называется `deleteCategory` (избегает конфликта с базовым `DatabaseConnectionUser.delete`). Аналогично `deleteSubtask` в `TaskSubtasksDao`.
  - DAO задач (`TaskDao`): `upsertTask` использует `insertOnConflictUpdate` (требует все NOT NULL-колонки в Companion). Для точечного обновления одной колонки (например, `allowed_member_ids` в `addAllowedMember`/`removeAllowedMember`) есть `updateAllowedMembers(taskId, allowedMemberIds)` — обычный `UPDATE`, не требующий полного companion.

## Связи

- `app_bloc_observer.dart` использует `AppLogger`.
- `main.dart` вызывает `SupabaseConfig`, `AppLogger`, `HomeWidgetService.initialize()`, `ReminderService.instance.initialize()`.
- `HomeWidgetService` импортирует `Task` из tasks feature.
- `RealtimeTasksSubscriptionMixin` используется в `TodayPage` и `ScheduledPage`.
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
