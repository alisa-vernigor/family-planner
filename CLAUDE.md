# Family Planner

Flutter-приложение для планирования семейных дел с распределением задач между участниками.

## Stack

| Компонент | Технология |
|-----------|-----------|
| **Язык** | Dart 3.12+ (sealed classes, records, pattern matching) |
| **Фреймворк** | Flutter — Material 3, `flutter_localizations` (русский/английский) |
| **State Management** | flutter_bloc 9.x (Cubit + sealed states, BlocObserver) |
| **Backend** | Supabase (PostgreSQL, Auth, Storage, Realtime) |
| **Database** | PostgreSQL с RLS, RPC (plpgsql), триггерами, enum'ами |
| **Логирование** | logger 2.x через `AppLogger` |
| **Равенство** | equatable 2.x для всех моделей |
| **Тесты** | flutter_test + bloc_test 10.x + mocktail 1.x |
| **Виджет** | home_widget 0.9.x (Android) |
| **Линтер** | flutter_lints 6.x |
| **Env** | flutter_dotenv 6.x |
| **Изображения** | image_picker 1.x |

## Быстрый старт (каждый раз в начале сессии)

1. **Команды** — `make test` (тесты), `make coverage`, `dart analyze lib` (анализ), `dart run build_runner build` (регенерация Drift после смены таблиц).
2. **Главные конвенции**, которые ломают компиляцию/тесты, если забыть:
   - `Task.copyWith` использует `_Sentinel` — при добавлении nullable-поля добавь его в `copyWith` и `props`.
   - Изменение интерфейса `TaskRepository` → обновить все ручные тестовые фейки (см. «Изменение интерфейса TaskRepository»).
   - Добавление колонки Drift → `schemaVersion++` + `MigrationStrategy.onUpgrade` + `build_runner` (см. `lib/core/CLAUDE.md`).
3. **Куда смотреть по фичам** — у каждой feature есть свой `CLAUDE.md` (`lib/features/<feature>/CLAUDE.md`, `lib/core/CLAUDE.md`, `lib/app/CLAUDE.md`) с актуальной картой файлов.
4. **База** — Supabase с локальным `supabase/migrations/`. Новая миграция = новый файл с датой; применение не автоматическое.

## Структура проекта

```
family-planner/
├── lib/
│   ├── main.dart                          # Точка входа: dotenv → Supabase → AppDatabase → runApp
│   ├── app/
│   │   ├── app.dart                       # FamilyPlannerApp — DI + MaterialApp
│   │   ├── app_bloc_observer.dart         # Логирование событий BLoC
│   │   └── theme.dart                     # Material 3 тема
│   ├── core/
│   │   ├── config/supabase_config.dart    # SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY
│   │   ├── logging/app_logger.dart        # Обёртка logger package
│   │   ├── database/                      # Drift/SQLite (offline-first): AppDatabase, tables/, daos/
│   │   ├── sync/                          # SyncProcessor + SyncCubit (очередь мутаций offline)
│   │   ├── mixins/                        # RealtimeTasksSubscriptionMixin, OptimisticTaskOperationsMixin
│   │   ├── services/                      # home_widget_service, connectivity_service
│   │   └── widgets/                       # offline_indicator
│   └── features/
│       ├── auth/          # Аутентификация (sign up, sign in, sign out)
│       ├── households/    # Семьи (CRUD, участники, приглашения)
│       ├── tasks/         # Задачи (сущности, use cases, репозиторий, виджеты, формы)
│       ├── today/         # Экран «Сегодня» (задачи на день)
│       ├── scheduled/     # Экран «Запланированные» (все будущие задачи)
│       └── profile/       # Профиль (настройки, аватар, публичная страница со статистикой)
├── supabase/
│   └── migrations/        # 7 миграций (initial → pinned_member → fix_leave → fix_rls → avatars → priority → recurrence_editing)
├── test/
│   ├── app/               # Тесты App и AppBlocObserver
│   ├── core/              # Тесты logging, database, sync
│   └── features/          # Тесты по фичам (entities, use cases, cubits, widgets)
├── scripts/
│   └── check_coverage.sh  # Скрипт проверки покрытия
└── Makefile               # test, test-watch, coverage, coverage-report
```

## Архитектура

### Clean Architecture (feature-first)

Каждая фича делится на слои:

- **domain/entities/** — модели данных (Equatable)
- **domain/repositories/** — абстрактные контракты (abstract interface class)
- **domain/use_cases/** — бизнес-логика (по одному классу на операцию)
- **domain/services/** — утилиты без сайд-эффектов
- **data/repositories/** — имплементации через Supabase
- **presentation/cubit/** — BLoC/Cubit (состояния через sealed class)
- **presentation/pages/** — экраны (StatelessWidget / StatefulWidget)
- **presentation/widgets/** — переиспользуемые виджеты

### DI

Репозитории создаются в `app.dart` и пробрасываются через `RepositoryProvider`.
Cubit'ы создаются либо глобально (AuthCubit, HouseholdCubit, HouseholdInvitationsCubit),
либо локально на страницах через `BlocProvider`.

### Navigation

```
main.dart → FamilyPlannerApp → AuthGate
  ├── AuthPage / EmailConfirmationPage (не аутентифицирован)
  └── HouseholdGate (аутентифицирован)
        ├── _EmptyShell (нет семей: CreateHouseholdPage / приглашения)
        └── _AppShell (есть семьи)
              ├── Tab 0: TodayPage (задачи на сегодня)
              └── Tab 1: ScheduledPage (запланированные задачи)
```

## Database (Supabase / PostgreSQL)

### Ключевые таблицы

- `profiles` — пользователи (создаются триггером на `auth.users`)
- `households` — семьи
- `household_members` — members (owner/member); PK = (household_id, profile_id)
- `household_invitations` — приглашения по email
- `task_templates` — шаблоны повторяющихся задач
- `task_occurrences` — экземпляры задач (основная таблица)
- `task_occurrence_allowed_members` — кто может выполнять задачу
- `task_subtasks` — подзадачи
- `task_categories` — категории

### RPC Functions

`create_household`, `delete_household`, `update_household_name`,
`create_household_invitation`, `accept_household_invitation`, `decline_household_invitation`,
`leave_household`, `remove_household_member`,
`create_task_occurrence`, `create_recurring_task_template`, `generate_recurring_task_occurrences`,
`pause_task_template`, `resume_task_template`, `update_task_template`,
`get_household_name_for_invitation`, `get_profile_stats`

### Offline-first (Drift + sync queue)

- **Чтение** — из локального SQLite (`DriftTaskRepository`), при онлайне сначала фетч с Supabase в кэш.
- **Запись** — сразу в локальную БД + `SyncQueueDao.enqueue(...)` с операцией. Когда интернет появится — `SyncProcessor.processPending()` реплеит очередь FIFO.
- **Операции очереди**: `CREATE`, `UPDATE`, `DELETE`, `PATCH_STATUS`, `ADD_ALLOWED`, `REMOVE_ALLOWED`, `UPDATE_TEMPLATE` (обработка в `lib/core/sync/sync_processor.dart`).
- **Ди** в `main.dart`: на нативных платформах `AppDatabase` (не null) → `DriftTaskRepository`; на web (null) → `SupabaseTaskRepository`. Выбор в `app.dart`.
- **Realtime**: экраны подписываются на `task_occurrences`, debounce 1.5s → `_silentReload`. После редактирования серии из другого клиента изменения прилетят через realtime.

### Безопасность

- RLS включён на всех таблицах
- RPC functions — SECURITY DEFINER с проверкой `auth.uid()` и `is_household_member`/`is_household_owner`
- Миграция `20260727_fix_rls_security` закрыла profile enumeration и другие уязвимости

## Ключевые моменты разработки

### Task

- `Task.copyWith` использует `_Sentinel` для различения `null` (сбросить) и `не передано` (оставить)
- `effectivePriority` возвращает приоритет по умолчанию (4 — не срочно и не важно) если `priority == null`
- `patchStatus` — оптимизация: 3 поля вместо 11 для частого complete/uncomplete
- `isRecurring` — `templateId != null && recurrence != null` (задача из серии повторений)
- `SortSelector` + `EisenhowerMatrixView` — на экране «Запланированные»

### Повторяющиеся задачи (recurring)

Полная карта — в `lib/features/tasks/CLAUDE.md`. Кратко:
- Шаблон (`task_templates`) ↔ экземпляры (`task_occurrences.template_id`).
- `Task` несёт `templateId` + `recurrence` + даты начала/конца (из вложенного select шаблона).
- Редактирование серии — через scope-выбор (3 опции как в Google Calendar) → RPC `update_task_template` (см. memory `recurrence-edit-scope`).
- UI повторения — переиспользуемый `RecurrenceEditor` + `RecurrenceDraft`.

### Realtime

- Оба экрана (Today, Scheduled) подписываются на `task_occurrences` через Supabase Realtime
- Debounce 1.5s: группа событий схлопывается в один reload
- Канал пересоздаётся при смене household

### Оптимистичные обновления

- Complete / uncomplete / assign / delete — сначала меняем UI через cubit, потом отправляем запрос
- При ошибке — откат (reload с сервера)

### Распределение задач

- Greedy-алгебра: нераспределённые задачи назначаются наименее загруженному члену семьи
- Закреплённые задачи (pinned) не перераспределяются
- Учитывается уже назначенная нагрузка в минутах

### Аватары

- Supabase Storage, bucket `avatars` (public, 5MB limit)
- Путь: `{profileId}/avatar.{ext}`
- Кэш Flutter чистится явно после загрузки/удаления
- К URL добавляется `?t=timestamp` для обхода кэширования

### Тестирование

- `flutter test` — запуск тестов
- `make coverage` — тесты с coverage
- `make coverage-report` — HTML-отчёт
- Используются `bloc_test` (для cubit'ов) и `mocktail` (для моков)

### Изменение интерфейса `TaskRepository`

`TaskRepository` (абстрактный интерфейс) реализуется НЕ только в `lib/`, но и во множестве тестовых фейков. При добавлении/изменении метода интерфейса **обязательно обнови ВСЕ ручные фейки** — mocktail-моки (`extends Mock implements TaskRepository`) обновлять не нужно (noSuchMethod).

Ручные фейки (`implements TaskRepository`, не `extends Mock`) — их ищи через:
```bash
grep -rn "implements TaskRepository" test --include='*.dart'
```
и обновляй в каждом: два impl в `test/features/edge_coverage_test.dart`, два в `test/features/final_coverage_test.dart`, по одному в `remaining_coverage_test.dart`, `exceptions_and_entities_test.dart`, `create_task_use_case_test.dart`, `complete_task_use_case_test.dart`, `distribute_tasks_use_case_test.dart`, `task_completion_cubit_test.dart`, `task_actions_cubit_test.dart`, `create_task_sheet_recurrence_test.dart`, `today_tasks_cubit_test.dart`, `scheduled_tasks_cubit_test.dart`, `update_task_cubit_test.dart` (×2 — tasks и scheduled). Mocktail-моки в `mock_repository_factory.dart` и `create_task_cubit_test.dart` — не трогать.

Новые тесты клади рядом: `test/features/tasks/domain/use_cases/`, `test/features/tasks/presentation/cubit/`, `test/features/tasks/presentation/widgets/`.

### Виджет (Android)

- Home Widget через `home_widget` package
- Фоновый изолят `interactiveCallback` для toggle задачи
- Сессия Supabase сохраняется в SharedPreferences для работы в фоне

## Чеклист перед сдачей работы

1. `dart analyze lib test` — ноль ошибок и предупреждений (info — можно, если pre-existing).
2. `flutter test` — все тесты зелёные.
3. Если менял Drift-таблицы: `dart run build_runner build` отработал, `.g.dart` закоммичен.
4. Если менял SQL: новая миграция в `supabase/migrations/`, применил в БД (напоминание пользователю).
5. Обновил feature-`CLAUDE.md`, если менял архитектуру фичи (чтобы не переисследовать в следующий раз).

## Правило: держать документацию актуальной

**Это правило — ОБЯЗАТЕЛЬНОЕ, не опциональное.** Пользователь явно попросил делать следующие запуски быстрее, а основная причина медленных задач — переисследование устаревших карт.

Когда делаешь любые изменения, которые влияют на структуру/архитектуру кода, **в том же заходе обнови соответствующие `CLAUDE.md`**:

- Изменил интерфейс `TaskRepository` / добавил метод → обнови `lib/features/tasks/CLAUDE.md`.
- Изменил схему Drift/колонку → обнови `lib/core/CLAUDE.md`.
- Добавил сущность/виджет/фичу → отметь в CLAUDE.md фичи.
- Добавил RPC/миграцию → обнови список в корневом `CLAUDE.md` и/или фичи.
- Изменил DI/navigation → обнови `lib/app/CLAUDE.md` и корневой.

Правило для меня (как для модели): **если я добавил/изменил код и НЕ обновил документацию — это незаконченная работа**. Документация обновляется в том же коммите/заходе, что и код.

Структура: корневой `CLAUDE.md` (обзор, стек, БД, конвенции), `lib/core/CLAUDE.md` (инфраструктура, Drift-миграции), `lib/app/CLAUDE.md` (DI/navigation), по одному `lib/features/<feature>/CLAUDE.md` на фичу.
