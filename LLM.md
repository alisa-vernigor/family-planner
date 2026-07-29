# Family Planner — LLM Map

Dart 3.12+ Flutter + Supabase (PostgreSQL) приложение для семейного планирования задач. Clean Architecture, feature-first.

---

## 1. Navigation & DI

### Entry point

`main.dart` → `dotenv.load` → `Supabase.initialize` → `FamilyPlannerApp`

### Widget tree

```
FamilyPlannerApp
  MultiRepositoryProvider (3 repos: Task, Household, Profile)
    MultiBlocProvider (3 cubits: Auth, Household, HouseholdInvitations)
      MaterialApp
        AuthGate
          BlocBuilder<AuthCubit>
            AuthPage              ← когда не аутентифицирован
            EmailConfirmationPage ← после регистрации
            HouseholdGate         ← аутентифицирован
              BlocBuilder<HouseholdCubit, HouseholdState>
                EmptyShell        ← нет семей
                  CreateHouseholdPage / Invitations
                AppShell          ← есть семьи
                  AppBar: dropdown выбора семьи + actions
                  IndexedStack:
                    [0] TodayPage      (BlocProvider: TodayTasksCubit, TaskCompletionCubit, TaskActionsCubit)
                    [1] ScheduledPage  (BlocProvider: ScheduledTasksCubit + локальные TaskCompletion/ TaskActions)
                  NavigationBar (2 таба)
```

### Repository DI (создаются в `app.dart`, пробрасываются через RepositoryProvider)

| Репозиторий | Имплементация |
|---|---|
| `TaskRepository` | `SupabaseTaskRepository` |
| `HouseholdRepository` | `SupabaseHouseholdRepository` |
| `ProfileRepository` | `SupabaseProfileRepository` |

### Global cubits (создаются в `app.dart`)

- `AuthCubit` — слушает `onAuthStateChange`
- `HouseholdCubit` — CRUD семей
- `HouseholdInvitationsCubit` — приглашения

### Local cubits (создаются на страницах)

- `TodayTasksCubit` + `TaskCompletionCubit` + `TaskActionsCubit` — на `TodayPage`
- `ScheduledTasksCubit` (+ опционально TaskCompletion/Actions) — на `ScheduledPage`
- `ProfileCubit` — на `ProfilePage`
- `HouseholdMembersCubit` — на `HouseholdMembersPage`
- `CreateTaskCubit` / `UpdateTaskCubit` — в bottom sheets

---

## 2. Features

### auth (7 файлов, ~470 строк)

- `AuthCubit`: checkSession, signUp, signIn, signOut. Слушает `onAuthStateChange` (Supabase.instance.client).
- `AuthState`: Initial, Loading, Unauthenticated, Authenticated, EmailConfirmationRequired, Failure
- `AuthPage`: форма входа/регистрации с валидацией, индикатором сложности пароля

### households (15 файлов, ~1400 строк)

- `Household` (id, name), `HouseholdMember` (profileId, displayName, avatarUrl, role), `HouseholdInvitation` (id, householdId, householdName, invitedByDisplayName, createdAt, expiresAt)
- `SupabaseHouseholdRepository`: через RPC-функции (create/delete/update household, accept/decline/leave invitation, invite/remove member)
- `HouseholdCubit`: load, refresh, create, delete, update
- `HouseholdMembersCubit`: load, inviteByEmail, leave, remove
- `AppShell`: IndexedStack + NavigationBar, dropdown семей, badge приглашений, popup menu (rename, create, delete, profile, signout)

### tasks (ядро, 19 файлов, ~4800 строк)

**Domain entities:**

| Класс | Поля / смысл |
|---|---|
| `Task` (Equatable) | id, householdId, title, description, estimatedDurationMinutes, plannedFor, deadline, allowedMemberIds[], assignedMemberId, pinnedMemberId, status, createdAt, completedAt, updatedAt, priority. `copyWith` с `_Sentinel` для nullable. `patchStatus` — 3 поля вместо 11. `effectivePriority` → default 4 |
| `TaskStatus` | `pending \| completed \| skipped` |
| `EisenhowerPriority` | 4 квадранта: urgentImportant(1), notUrgentImportant(2), urgentNotImportant(3), notUrgentNotImportant(4) |
| `TaskRecurrence` | daily / weekly(weekdays[]) / intervalDays(int) |
| `CreateTaskParams` | householdId, title, description, estimatedDurationMinutes, plannedFor, deadline, recurrence?, priority?, ... |
| `TaskSortOption` | deadline, priority, duration, title, createdAt, plannedFor (+ static `apply`) |

**Use cases:**

- `CreateTaskUseCase`: валидирует title, duration, recurrence → `repository.create`
- `CompleteTaskUseCase`: проверяет `isCompleted` и `canBeCompletedBy` → `patchStatus` (3 поля)
- `UncompleteTaskUseCase`: `patchStatus` → pending
- `DeleteTaskUseCase`: `repository.delete`
- `UpdateTaskUseCase`: валидация → `repository.save`
- `AssignTaskUseCase` / `UnpinTaskUseCase` / `UpdateTaskPriorityUseCase`
- `GetForDayUseCase` / `GetScheduledUseCase` / `GetAllPendingUseCase`
- `DistributeTasksUseCase`: greedy-алгоритм — сортирует нераспределённые задачи по убыванию duration, назначает наименее загруженному. Игнорирует pinned. Сохраняет batched.

**Repository contract:**

```
getForDay(householdId, day) → List<Task>
getScheduledAfter(householdId, day) → List<Task>  (6 months ahead, non-completed)
getAllPending(householdId) → List<Task>  (7 days back, 200 limit)
create(params) → Task
save(task) → void  (с optimistic lock по updated_at)
patchStatus(taskId, status, completedByMemberId, completedAt, assignedMemberId) → void
delete(taskId) → void
addAllowedMember / removeAllowedMember
```

**Key implementation details in `SupabaseTaskRepository`:**

- `getForDay`: SELECT с JOIN `task_occurrence_allowed_members`
- `create`: одноразовые → RPC `create_task_occurrence`, повторяющиеся → `create_recurring_task_template`
- `save`: UPDATE с `eq('updated_at', ...)` — optimistic lock
- `_toTask`: парсинг joined allowed_members → `allowedMemberIds`
- `_taskFromCreatedRow`: после создания allowedMembers = `[currentUserId]`
- Post-creation: если указан assignedMemberId/pinnedMemberId → save + addAllowedMember

**Pages:**
- `CreateTaskSheet` / `EditTaskSheet` — bottom sheets: поля (название, описание, длительность, ответственный, повторение, дедлайн, приоритет)

**Widgets:**
- `TaskCard` (508 строк): чекбокс complete/uncomplete, popup menu (edit, assign, pin, delete), chips (duration, deadline, priority, assignee, date), swipe left→right (toggle status), swipe right→left (delete)
- `EisenhowerMatrixView` (805 строк): 4 квадранта. Adaptive layout (>600px → grid 2×2, иначе вертикальный стек). Drag & drop: LongPressDraggable → DragTarget для смены приоритета. `_MiniTaskCard` для grid, `TaskCard` для narrow.
- `PrioritySelector`, `SortSelector`, `AssigneePicker`

### today (4 файла, ~1300 строк)

- `TodayTasksCubit`: load (с Future.wait: tasks + members), refresh, distribute, optimistic replace/remove
- `TodayPage` (606 строк):
  - MultiBlocProvider + Realtime-подписка через `RealtimeTasksSubscriptionMixin`
  - `TaskListView`: 3 секции — Мои задачи / Задачи семьи / Неназначенные + `SectionHeader` + SortSelector
  - Batch-режим: long press → выбор нескольких → batch complete
  - SnackBar с "Отменить" при complete
  - 2 FAB: автораспределение + создание задачи

### scheduled (4 файла, ~950 строк)

- `ScheduledTasksCubit`: load (6 months), refresh, optimistic replace/remove
- `ScheduledPage` (545 строк): фильтры (Все/Мои/Без назначения), сортировка, переключение между списком и матрицей Эйзенхауэра
- `ScheduledTaskCard` (компактная, без свайпов)

### profile (12 файлов, ~1200 строк)

- `UserProfile` (id, displayName, avatarUrl, timezone, bio), `ProfileStats` (totalAssigned, completedTasks, completedThisWeek, completedThisMonth, completionRate)
- `SupabaseProfileRepository`: upload/remove avatar в Storage bucket `avatars/{profileId}/avatar.{ext}`. Очистка кэша через `PaintingBinding`. `getStats` через RPC (только для членов одного household)
- `ProfilePage`: публичная страница с аватаром + статистикой (4 stat cards + progress bar)
- `ProfileSettingsPage`: редактирование имени, био, загрузка/удаление аватара через ImagePicker
- `AvatarWidget`: 3 named конструктора (profile, member, URL)

### core (5 файлов, ~600 строк)

- `SupabaseConfig`: URL + key из .env / --dart-define
- `AppLogger`: обёртка над `logger` (debug/info/warning/error)
- `HomeWidgetService`: Android Home Widget интеграция — сохраняет сессию + задачи в SharedPreferences, фоновый `interactiveCallback` для toggle задачи
- `RealtimeTasksSubscriptionMixin`: Supabase Realtime подписка на `task_occurrences`, debounce 1.5s, пересоздание при смене household
- `OptimisticTaskOperationsMixin`: optimisticReplace, optimisticRemove, filterPendingDeletes, confirmDelete, cancelDelete. Используется TodayTasksCubit + ScheduledTasksCubit

---

## 3. Database (Supabase/PostgreSQL)

**Migrations** (6 файлов):
1. `20260727_initial_schema` — все таблицы, RLS, RPC, триггеры
2. `20260726_add_pinned_member_id` — колонка pinned для автораспределения
3. `20260727_fix_leave_household` — cleanup allowed_members при выходе
4. `20260727_fix_rls_security` — RLS hardening (profiles, members)
5. `20260728_avatars` — storage bucket avatars, profile bio, stats RPC
6. `20260729_add_priority` — priority INT колонка

**Key tables:**
- `profiles` — id, display_name, avatar_url, timezone, bio
- `households` — id, name
- `household_members` — (household_id, profile_id, role, joined_at); PK = (household_id, profile_id)
- `household_invitations` — id, household_id, email, invited_by, status, expires_at
- `task_templates` — recurring task templates
- `task_occurrences` — id, household_id, title, description, estimated_duration_minutes, planned_for, deadline_at, assigned_member_id, pinned_member_id, status, priority, completed_by_member_id, completed_at, created_at, updated_at
- `task_occurrence_allowed_members` — (task_occurrence_id, profile_id)
- `task_subtasks` — id, task_occurrence_id, title, is_completed
- `task_categories` — id, household_id, name, color

**RPC functions** (15+):
`create_household`, `delete_household`, `update_household_name`, `create_household_invitation`, `accept_household_invitation`, `decline_household_invitation`, `leave_household`, `remove_household_member`, `create_task_occurrence`, `create_recurring_task_template`, `generate_recurring_task_occurrences` (не вызвается из кода — триггер?), `pause_task_template`, `resume_task_template`, `get_household_name_for_invitation`, `get_profile_stats`

**Security:** RLS на всех таблицах. RPC functions — SECURITY DEFINER с проверкой auth.uid().

---

## 4. Data Flow Patterns

### Load
```
Page.initState → Cubit.load(householdId)
  → Future.wait([taskRepository.getForDay(...), householdRepository.getMembers(...)])
    → emit(Loaded(tasks, members))
```

### Complete (optimistic)
```
User taps complete → TaskCompletionCubit.completeTask(task, memberId)
  → UseCase.check(canBeCompletedBy, isCompleted)
    → repository.patchStatus(3 поля)
  → success → cubit emit Success(task) → Page listener: cubit.replaceTask(task)
  → SnackBar с "Отменить"
```

### Delete (optimistic)
```
User taps delete → showDialog → TodayTasksCubit.removeTask(taskId)
  → optimisticRemove (добавляет в _pendingDeleteIds, убирает из UI)
  → TaskActionsCubit.deleteTask(taskId)
    → repository.delete(taskId)
  → success → cubit.confirmDelete(taskId) / fail → cancelDelete + reload
```

### Real-time update (background)
```
Supabase Realtime → INSERT/UPDATE/DELETE на task_occurrences
  → debounce 1.5s → Cubit.refresh(householdId) → reload без спиннера
```

### Task distribution
```
DistributeTasksUseCase:
  1. Load all pending tasks for day + members
  2. Build workload map (existing assigned/pinned → minutes)
  3. Sort unassigned by duration DESC
  4. Greedy: each unassigned → least loaded member
  5. Save each updated task + addAllowedMember if needed
```

---

## 5. Key Technical Decisions

- **Task.copyWith + _Sentinel**: различает `null` (установить null) vs `не передано` (оставить как есть) — для nullable полей description, deadline, assignedMemberId, pinnedMemberId, completedAt, priority
- **Task.patchStatus**: оптимизация complete/uncomplete — UPDATE 3 полей вместо save (11 полей), минуя copyWith
- **Realtime debounce (1.5s)**: групповые операции не вызывают N релоадов; один релоад после паузы
- **Greedy distribution**: наименее загруженный member получает следующую задачу. Pinned-задачи не перераспределяются
- **Eisenhower matrix adaptive layout**: >600px → Grid 2×2 с _MiniTaskCard (compact), иначе вертикальный стек с TaskCard
- **Optimistic lock**: `save` использует `eq('updated_at', ...)` для предотвращения конфликтов
- **Feature barrel files**: `tasks.dart`, `households.dart`, `auth.dart`, `profile.dart` — экспортируют все публичные API фичи

---

## 6. Testing

- `flutter_test` + `bloc_test` + `mocktail`
- `make test` / `make coverage` / `make coverage-report`
- Структура: `test/app/`, `test/core/logging/`, `test/features/` (entities, use_cases, cubits, widgets)
