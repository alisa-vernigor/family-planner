# Tasks (lib/features/tasks/)

Ядро приложения: сущности задач, бизнес-логика (создание, выполнение, распределение, приоритеты, повторения).

## Содержимое

### domain/entities/

- **task.dart** — `Task` (Equatable). 20 полей: id, householdId, title, description, estimatedDurationMinutes, plannedFor, deadline, allowedMemberIds, assignedMemberId, pinnedMemberId, status, createdAt, completedAt, updatedAt, priority. Методы: `isCompleted`, `isPinned`, `canBeCompletedBy(memberId)`, `effectivePriority` (default 4), `copyWith` (с `_Sentinel` для nullable).
- **task_status.dart** — enum `TaskStatus.pending | completed | skipped`.
- **eisenhower_priority.dart** — enum `EisenhowerPriority` (1–4): `urgentImportant`, `notUrgentImportant`, `urgentNotImportant`, `notUrgentNotImportant`. `fromValue(int?)`, `value`, `label`.
- **task_recurrence.dart** — `TaskRecurrenceType` (daily, weekly, intervalDays) + `TaskRecurrence` (type, intervalDays?, weekdays[]).
- **create_task_params.dart** — `CreateTaskParams`: входные данные для создания задачи (включая опциональные recurrence, priority).
- **task_sort_option.dart** — enum `TaskSortOption` (deadline, priority, duration, title, createdAt, plannedFor). Статический метод `apply(List<Task>, TaskSortOption)` — сортировка.

### domain/repositories/

- **task_repository.dart** — абстрактный контракт: `getForDay`, `getScheduledAfter`, `getAllPending`, `create`, `save`, `patchStatus`, `delete`, `addAllowedMember`, `removeAllowedMember`.

### domain/services/

- **task_schedule.dart** — утилита `TaskSchedule`: статические методы `forDay`, `scheduledAfter`, `overdueBefore`, `forDateRange`.

### domain/use_cases/

- **create_task_use_case.dart** — `CreateTaskUseCase`: валидация title, duration, recurrence (weekly нужны weekdays, intervalDays > 0, даты). Делегирует `repository.create`.
- **complete_task_use_case.dart** — `CompleteTaskUseCase`: проверка `isCompleted` и `canBeCompletedBy`. Использует `patchStatus` (3 поля).
- **uncomplete_task_use_case.dart** — `UncompleteTaskUseCase`: проверка `isCompleted`, `patchStatus` в pending.
- **delete_task_use_case.dart** — `DeleteTaskUseCase`: делегирует `repository.delete`.
- **update_task_use_case.dart** — `UpdateTaskUseCase`: валидация, делегирует `repository.save`.
- **get_tasks_for_day_use_case.dart** — делегирует `repository.getForDay`.
- **get_all_pending_tasks_use_case.dart** — делегирует `repository.getAllPending`.
- **get_scheduled_tasks_use_case.dart** — делегирует `repository.getScheduledAfter`.
- **distribute_tasks_use_case.dart** — `DistributeTasksUseCase`: распределение нераспределённых задач между членами семьи через greedy-алгоритм (least loaded first). `DistributeTasksResult`.

### data/repositories/

- **supabase_task_repository.dart** — имплементация через Supabase:
  - SELECT задачи с JOIN `task_occurrence_allowed_members`.
  - CREATE: одноразовые через RPC `create_task_occurrence`, повторяющиеся через `create_recurring_task_template`.
  - SAVE: `update` с optimistic lock по `updated_at`.
  - `patchStatus`: обновляет 3 поля (status, completed_by_member_id, completed_at).
  - `_toTask`, `_taskFromCreatedRow`, `_parseNullableDateTime`, `_dateOnly`.
  - `TaskUserNotAuthenticatedException`.

### presentation/cubit/

- **create_task_cubit.dart** — `CreateTaskCubit`: `create(CreateTaskParams)`, состояния `CreateTaskState`.
- **create_task_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`.
- **update_task_cubit.dart** — `UpdateTaskCubit`: `update(Task)`, состояния `UpdateTaskState`.
- **update_task_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`.
- **task_completion_cubit.dart** — `TaskCompletionCubit`: `completeTask(task, memberId)`, обработка `TaskAlreadyCompletedException`, `TaskCompletionNotAllowedException`.
- **task_completion_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`. Используется также `TaskActionsCubit`.
- **task_actions_cubit.dart** — `TaskActionsCubit`: `uncompleteTask(task)`, `deleteTask(taskId)`.

### presentation/widgets/

- **task_card.dart** — `TaskCard`: полноценная карточка задачи с чекбоксом, меню действий, информационными чипами (длительность, дедлайн, приоритет, исполнитель). Swipe-to-complete/uncomplete/delete через `Dismissible`. Чипы: `_InfoChip`, `DeadlineChip`, `_AssigneeChip`, `_PriorityChip`.
- **eisenhower_matrix_view.dart** — `EisenhowerMatrixView`: представление задач в 4 квадрантах (матрица Эйзенхауэра). Поддержка drag & drop для смены приоритета. Адаптивный layout: на широких экранах грид 2×2, на узких — вертикальный список. `_QuadGrid`, `_QuadrantSection`, `_MiniTaskCard`.
- **priority_selector.dart** — `PrioritySelector`: горизонтальный выбор приоритета с визуальными стилями. Кнопка «Сбросить».
- **sort_selector.dart** — `SortSelector`: горизонтальный выбор варианта сортировки задач.
- **assignee_picker.dart** — `showAssigneePicker`: bottom sheet выбора ответственного.

### presentation/pages/

- **create_task_sheet.dart** — `showCreateTaskSheet`: модальный bottom sheet создания задачи. `CreateTaskSheet` (StatefulWidget): форма с полями (название, описание, длительность, ответственный, повторение, дедлайн, приоритет). `_RecurrenceSummary` — сводка повторения с предпросмотром дат. `_WeekdayChip` — выбор дней недели.
- **edit_task_sheet.dart** — `showEditTaskSheet`: модальный bottom sheet редактирования задачи. Аналогично create, но предзаполнено из `Task`.

## Связи

- Основная фича, от которой зависят `today` и `scheduled`.
- `Task` — центральная доменная модель, импортируется всеми feature-слоями.
- `CreateTaskSheet` и `EditTaskSheet` вызываются из `TodayPage` и `ScheduledPage`.
- Использует `HouseholdMember` (из households) для виджетов назначения.
- `SupabaseTaskRepository` зависит от `SupabaseClient`.
- `DistributeTasksUseCase` зависит от `TaskRepository` + `HouseholdRepository`.
