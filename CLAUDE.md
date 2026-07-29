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

## Структура проекта

```
family-planner/
├── lib/
│   ├── main.dart                          # Точка входа: dotenv → Supabase → runApp
│   ├── app/
│   │   ├── app.dart                       # FamilyPlannerApp — DI + MaterialApp
│   │   ├── app_bloc_observer.dart         # Логирование событий BLoC
│   │   └── theme.dart                     # Material 3 тема
│   ├── core/
│   │   ├── config/supabase_config.dart    # SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY
│   │   ├── logging/app_logger.dart        # Обёртка logger package
│   │   └── services/home_widget_service.dart # Android Home Widget интеграция
│   └── features/
│       ├── auth/          # Аутентификация (sign up, sign in, sign out)
│       ├── households/    # Семьи (CRUD, участники, приглашения)
│       ├── tasks/         # Задачи (сущности, use cases, репозиторий, виджеты, формы)
│       ├── today/         # Экран «Сегодня» (задачи на день)
│       ├── scheduled/     # Экран «Запланированные» (все будущие задачи)
│       └── profile/       # Профиль (настройки, аватар, публичная страница со статистикой)
├── supabase/
│   └── migrations/        # 6 миграций (initial → pinned_member → fix_leave → fix_rls → avatars → priority)
├── test/
│   ├── app/               # Тесты App и AppBlocObserver
│   ├── core/logging/      # Тесты AppLogger
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
`pause_task_template`, `resume_task_template`,
`get_household_name_for_invitation`, `get_profile_stats`

### Безопасность

- RLS включён на всех таблицах
- RPC functions — SECURITY DEFINER с проверкой `auth.uid()` и `is_household_member`/`is_household_owner`
- Миграция `20260727_fix_rls_security` закрыла profile enumeration и другие уязвимости

## Ключевые моменты разработки

### Task

- `Task.copyWith` использует `_Sentinel` для различения `null` (сбросить) и `не передано` (оставить)
- `effectivePriority` возвращает приоритет по умолчанию (4 — не срочно и не важно) если `priority == null`
- `patchStatus` — оптимизация: 3 поля вместо 11 для частого complete/uncomplete
- `SortSelector` + `EisenhowerMatrixView` — на экране «Запланированные»

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

### Виджет (Android)

- Home Widget через `home_widget` package
- Фоновый изолят `interactiveCallback` для toggle задачи
- Сессия Supabase сохраняется в SharedPreferences для работы в фоне
