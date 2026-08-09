# Tasks (lib/features/tasks/)

Ядро приложения: сущности задач, бизнес-логика (создание, выполнение, распределение, приоритеты, повторения).

## Содержимое

### domain/entities/

- **task.dart** — `Task` (Equatable). Поля: id, householdId, title, description, estimatedDurationMinutes, plannedFor, deadline, allowedMemberIds, assignedMemberId, pinnedMemberId, status, createdAt, completedAt, updatedAt, priority, **templateId**, **recurrence**, **recurrenceStartDate**, **recurrenceEndDate**, **reminderMinutesBefore**, **categoryId**, **plannedTime** (`Duration?` — время начала в минутах от полуночи; `null` — без времени/весь день), **templateActive** (`bool?` — `task_templates.is_active`; `false` = серия на паузе). Методы: `isCompleted`, `isSkipped`, `isPinned`, **`isRecurring`** (templateId != null && recurrence != null), **`isSeriesPaused`** (templateActive == false), `canBeCompletedBy(memberId)`, `effectivePriority` (default 4), `plannedTimeLabel` (HH:MM строка), `copyWith` (с `_Sentinel` для nullable).
- **task_status.dart** — enum `TaskStatus.pending | completed | skipped`.
- **eisenhower_priority.dart** — enum `EisenhowerPriority` (1–4): `urgentImportant`, `notUrgentImportant`, `urgentNotImportant`, `notUrgentNotImportant`. `fromValue(int?)`, `value`, `label`.
- **task_recurrence.dart** — `TaskRecurrenceType` (daily, weekly, intervalDays) + `TaskRecurrence` (type, intervalDays?, weekdays[]).
- **create_task_params.dart** — `CreateTaskParams`: входные данные для создания задачи (включая опциональные recurrence, priority, reminderMinutesBefore, categoryId, **plannedTime**).
- **task_category.dart** — `TaskCategory` (id, householdId, name, colorHex, iconName).
- **task_subtask.dart** — `TaskSubtask` (id, taskId, title, position, isCompleted, createdAt, completedAt?). `copyWith` с `_Sentinel`, `toggle()`.
- **create_task_category_params.dart** — `CreateTaskCategoryParams` (householdId, name, colorHex, iconName).
- **create_task_subtask_params.dart** — `CreateTaskSubtaskParams` (taskId, title).
- **update_recurring_task_params.dart** — `RecurrenceEditScope` (onlyThis / thisAndFollowing / all, как в Google Calendar) + `UpdateRecurringTaskParams` (task, recurrence, scope, recurrenceStartDate?, recurrenceEndDate?).
- **task_sort_option.dart** — enum `TaskSortOption` (deadline, priority, duration, title, createdAt, plannedFor). Статический метод `apply(List<Task>, TaskSortOption)` — сортировка.

### domain/repositories/

- **task_repository.dart** — абстрактный контракт: `getForDay`, `getScheduledAfter`, `getAllPending`, `create`, `save`, **`updateTemplate`**, `patchStatus`, `delete`, `addAllowedMember`, `removeAllowedMember`, **`pauseTemplate(templateId)`**, **`resumeTemplate(templateId)`**.
  - **ВАЖНО:** при изменении интерфейса обновляй ВСЕ тестовые фейки — они перечислены в корневом CLAUDE.md в разделе «Тестирование».
- **task_category_repository.dart** — `getForHousehold`, `create`, `update`, `delete`.
- **task_subtask_repository.dart** — `getForTask`, `create`, `toggle`, `updateTitle`, `reorder`, `delete`.

### domain/services/

- **task_schedule.dart** — утилита `TaskSchedule`: статические методы `forDay`, `scheduledAfter`, `overdueBefore`, `forDateRange`.
- **category_color.dart** — палитра `kCategoryColorHexes`, `colorFromHex(String?, {fallback})`, `categoryBackground(Color)`.

### domain/use_cases/

- **create_task_use_case.dart** — `CreateTaskUseCase`: валидация title, duration, recurrence (weekly нужны weekdays, intervalDays > 0, даты). Делегирует `repository.create`. **`validateCreateTaskParams(CreateTaskParams)`** — вынесенная top-level функция-валидатор (возвращает params с обрезанными title/description); переиспользуется в `TaskImportUseCase` (импорт создаёт задачу напрямую через repository, но валидация та же). **Важно:** при изменении полей `CreateTaskParams` проверь, что они прокидываются и в `validateCreateTaskParams` (лакуна ранее теряла priority/plannedTime/categoryId и др.).
- **complete_task_use_case.dart** — `CompleteTaskUseCase`: проверка `isCompleted` и `canBeCompletedBy`. Использует `patchStatus` (3 поля).
- **uncomplete_task_use_case.dart** — `UncompleteTaskUseCase`: проверка `isCompleted`, `patchStatus` в pending.
- **skip_task_use_case.dart** — `SkipTaskUseCase`: пометить задачу как пропущенную (`patchStatus` в `skipped`). Исчезает из Today/Scheduled, остаётся в истории. `TaskAlreadySkippedException`.
- **delete_task_use_case.dart** — `DeleteTaskUseCase`: делегирует `repository.delete`.
- **update_task_use_case.dart** — `UpdateTaskUseCase`: `call` (обычное сохранение, валидация title/duration), `updateRecurring` (для серии: валидация recurrence через исключения из create_task_use_case, делегирует `repository.updateTemplate`).
- **get_tasks_for_day_use_case.dart** — делегирует `repository.getForDay`.
- **get_all_pending_tasks_use_case.dart** — делегирует `repository.getAllPending`.
- **get_scheduled_tasks_use_case.dart** — делегирует `repository.getScheduledAfter`.
- **distribute_tasks_use_case.dart** — `DistributeTasksUseCase`: распределение нераспределённых задач между членами семьи через greedy-алгоритм (least loaded first). `DistributeTasksResult`.
- **pause_task_template_use_case.dart** — `PauseTaskTemplateUseCase`: пауза серии (`repository.pauseTemplate`).
- **resume_task_template_use_case.dart** — `ResumeTaskTemplateUseCase`: возобновление серии (`repository.resumeTemplate`).

### data/repositories/

- **supabase_task_repository.dart** — имплементация через Supabase:
  - SELECT задачи с JOIN `task_occurrence_allowed_members` и вложенным `task_templates(recurrence_type, interval_days, weekdays, recurrence_start_date, recurrence_end_date, is_active)` (для `templateId`/`recurrence`/`templateActive` на Task).
  - Списки (`getScheduledAfter`, `getAllPending`) исключают `completed` **и `skipped`** через `.not('status', 'in', [...])`; `getForDay` — без фильтра статуса (Today показывает completed с зачёркиванием).
  - CREATE: одноразовые через RPC `create_task_occurrence`, повторяющиеся через `create_recurring_task_template` (оба принимают `p_planned_time`).
  - SAVE: `update` с optimistic lock по `updated_at` (пишет `planned_time`).
  - **updateTemplate**: RPC `update_task_template` (см. «Повторяющиеся задачи» ниже), передаёт `p_planned_time`.
  - **pauseTemplate/resumeTemplate**: RPC `pause_task_template` / `resume_task_template` с `p_task_template_id`.
  - `patchStatus`: обновляет 3 поля (status, completed_by_member_id, completed_at). Поддерживает любой статус, включая `skipped`.
  - `_toTask`, `_taskFromCreatedRow`, `_recurrenceFromRow`, `_parseNullableDateTime`, `_dateOnly`, `_parseTime`/`_timeToString`.
  - `TaskUserNotAuthenticatedException`.
- **drift_task_repository.dart** — offline-first имплементация `TaskRepository` через Drift/SQLite: читает из кэша, при онлайне фетчит с Supabase; пишет в SQLite + очередь `SyncQueueDao`. Обрабатывает `CREATE`, `UPDATE`, `DELETE`, `PATCH_STATUS`, `ADD_ALLOWED`, `REMOVE_ALLOWED`, `UPDATE_TEMPLATE`, **`PAUSE_TEMPLATE`, `RESUME_TEMPLATE`** (payload = `{'p_task_template_id': templateId}` + householdId). `category_id`, `reminder_minutes_before`, `planned_time` (минуты от полуночи в Drift-колонке `plannedTime`) и **`template_active`** (`templateActive`, nullable bool) маппятся в/из Drift-колонок через хелперы `_timeToString`/`_minutesFromTime`/`_durationFromMinutes`. Локальные запросы (`TaskDao.getForDay`/`getScheduledAfter`/`getAllPending`) исключают `skipped`.
  - **addAllowedMember/removeAllowedMember** обновляют `allowed_member_ids` через `TaskDao.updateAllowedMembers` (точечный `UPDATE` колонки, а не полный `insertOnConflictUpdate`): частичный `TaskOccurrencesCompanion` в `upsertTask` падает с `InvalidDataException` (Drift требует все NOT NULL-поля).
- **supabase_task_category_repository.dart** — `TaskCategoryRepository` напрямую через Supabase (RLS).
- **drift_task_category_repository.dart** — кэш категорий в SQLite; чтение из кэша с фетчем на сервер при онлайне, записи напрямую в Supabase (без offline-очереди). **Доменный `TaskCategory` алиасится `as domain`** из-за конфликта с Drift row.
- **supabase_task_subtask_repository.dart** — `TaskSubtaskRepository` напрямую через Supabase (RLS).
- **drift_task_subtask_repository.dart** — offline-first: чтение из кэша + фетч на сервер, записи в SQLite + sync-очередь (`SUBTASK_CREATE/UPDATE/DELETE`). **Доменный `TaskSubtask` алиасится `as domain`** из-за конфликта с Drift row; DAO-метод удаления — `deleteSubtask`.

## Повторяющиеся задачи (recurring) — архитектура

Повторяющаяся задача = **шаблон** (`task_templates`) + **экземпляры** (`task_occurrences`, каждый имеет `template_id`).

- **Create** (`CreateTaskSheet` → RPC `create_recurring_task_template`): создаёт шаблон, первый экземпляр и генерирует экземпляры на ~30 дней (`generate_recurring_task_occurrences`).
- **Read**: каждый экземпляр возвращается как `Task` с заполненными `templateId` + `recurrence` + `recurrenceStartDate/EndDate` (из вложенного select шаблона). Это позволяет UI знать, что задача повторяющаяся (`task.isRecurring`).
- **Edit** (`EditTaskSheet`): для `task.templateId != null` сначала показывается **scope-диалог** (`showRecurrenceEditScopeDialog`) — 3 опции как в Google Calendar. Затем:
  - `onlyThis` → обычное `save` (один экземпляр).
  - `thisAndFollowing` / `all` → **`updateTemplate`** (RPC `update_task_template`), который обновляет шаблон и пересобирает экземпляры.
- **RPC `update_task_template`** (миграция `20260807_recurrence_editing.sql`): валидация как при create; для `only_this` обновляет только указанный экземпляр; иначе обновляет шаблон + метаданные экземпляров в зоне изменений, а при смене расписания удаляет несовпадающие pending-экземпляры (с `planned_for >= current_date`), сохраняет completed, и перегенерирует. Перегенерация идёт через `generate_recurring_task_occurrences(current_date + 30, reshape_from)` — **от даты зоны изменений, а не от начала серии** (миграция `20260809_fix_recurring_overloads_and_duplicates.sql`): иначе `this_and_following` создавал лишние экземпляры в прошлом сегменте. Та же миграция убрала накопившиеся перегрузки `create_task_occurrence`/`create_recurring_task_template` (риск 42725).
- **UI-виджет повторения**: `RecurrenceEditor` + `RecurrenceDraft` (в `presentation/widgets/recurrence_editor.dart`) — переиспользуется в CreateTaskSheet и EditTaskSheet. Управляет собственным состоянием (uncontrolled: `initial` читается только в initState), `buildRecurrence()` возвращает `null` при выключенном повторе, `showEnableSwitch` скрывает переключатель в edit-режиме.
- **Offline** (`DriftTaskRepository.updateTemplate`): обновляет локальный экземпляр + очередь `UPDATE_TEMPLATE` с полным payload RPC. `SyncProcessor` обрабатывает операцию.
- **Пауза/возобновление серии**: пункт «Поставить на паузу»/«Возобновить серию» в меню карточки (`TaskCard`, `ScheduledTaskCard`, `CalendarView`; бейдж «Серия на паузе», когда `task.isSeriesPaused`). Вызывается `PauseTaskTemplateUseCase`/`ResumeTaskTemplateUseCase` → RPC `pause_task_template`/`resume_task_template` (миграция `20260808_pause_resume.sql`):
  - `pause_task_template`: `is_active=false` + удаляет будущие pending-экземпляры (сохраняя историю и один «якорный» экземпляр).
  - `resume_task_template`: `is_active=true` + перегенерирует на 30 дней (`generate_recurring_task_occurrences(current_date + 30)`).
  - Offline: `DriftTaskRepository.pauseTemplate/resumeTemplate` обновляют `template_active` локально у всех экземпляров серии + очередь `PAUSE_TEMPLATE`/`RESUME_TEMPLATE`.

### presentation/cubit/

- **create_task_cubit.dart** — `CreateTaskCubit`: `create(CreateTaskParams)`, состояния `CreateTaskState`. После успешного создания планирует push-напоминание (`_scheduleReminder`, если `reminderMinutesBefore != null`).
- **create_task_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`.
- **update_task_cubit.dart** — `UpdateTaskCubit`: `update(Task)` / `updateTemplate(...)`, состояния `UpdateTaskState`. Синхронизирует напоминание (`_syncReminder` — cancel + reschedule).
- **update_task_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`.
- **task_completion_cubit.dart** — `TaskCompletionCubit`: `completeTask(task, memberId)`, обработка `TaskAlreadyCompletedException`, `TaskCompletionNotAllowedException`. При выполнении отменяет напоминание.
- **task_completion_state.dart** — `Initial`, `InProgress`, `Success`, `Failure`. Используется также `TaskActionsCubit`.
- **task_actions_cubit.dart** — `TaskActionsCubit`: `uncompleteTask(task)` (пере-планирует напоминание), `skipTask(task)` (статус `skipped`, отменяет напоминание), `deleteTask(taskId)` (отменяет напоминание). Принимает `SkipTaskUseCase`.

### presentation/widgets/

- **task_card.dart** — `TaskCard`: полноценная карточка задачи с чекбоксом, меню действий, информационными чипами (длительность, дедлайн, приоритет, исполнитель, **категория** через `CategoryChip`, **время начала** `plannedTimeLabel`, **бейдж «Серия на паузе»**). Swipe-to-complete/uncomplete/delete через `Dismissible`. Принимает опциональный `category: TaskCategory?`, `onTogglePause: VoidCallback?` (пункт меню для серий) и `onSkip: VoidCallback?` (пункт «Пропустить»). Чипы: `_InfoChip`, `DeadlineChip`, `_AssigneeChip`, `_PriorityChip`.
- **eisenhower_matrix_view.dart** — `EisenhowerMatrixView`: представление задач в 4 квадрантах (матрица Эйзенхауэра). Поддержка drag & drop для смены приоритета. Адаптивный layout: на широких экранах грид 2×2, на узких — вертикальный список. `_QuadGrid`, `_QuadrantSection`, `_MiniTaskCard`.
- **priority_selector.dart** — `PrioritySelector`: горизонтальный выбор приоритета с визуальными стилями. Кнопка «Сбросить».
- **sort_selector.dart** — `SortSelector`: горизонтальный выбор варианта сортировки задач.
- **assignee_picker.dart** — `showAssigneePicker`: bottom sheet выбора ответственного.
- **reminder_selector.dart** — `ReminderSelector`: выпадающий выбор напоминания (`null`, 5/15/30/60 мин, 1440 = за день).
- **start_time_field.dart** — `StartTimeField`: поле выбора времени начала задачи (`Duration?`; `null` — весь день). Используется в CreateTaskSheet и EditTaskSheet. Кнопка «Убрать время» сбрасывает в `null`.
- **category_chip.dart** — `CategoryChip`: цветной чип категории (цвет из `colorHex`).
- **category_picker.dart** — `showCategoryPicker`: bottom sheet выбора категории + создание новой (диалог с палитрой).
- **category_field.dart** — `CategoryField`: поле выбора категории для форм (само загружает список, поддерживает создание).
- **subtask_editor.dart** — `SubtaskEditor`: инлайн-список подзадач (чекбоксы, добавление, удаление свайпом, drag&drop) для `EditTaskSheet`.
  - **ВАЖНО:** при `onReorder == null` рендерит обычный `ListView` (без drag&drop). НЕ передавать `onReorder: null` в `ReorderableListView` с непустым списком — Flutter требует (assert) заданный `onReorder`/`onReorderItem`. Раньше `SubtaskEditor` без `onReorder` + подзадачи падал с assertion.

### presentation/pages/

- **create_task_sheet.dart** — `showCreateTaskSheet`: модальный bottom sheet создания задачи. `CreateTaskSheet` (StatefulWidget): форма с полями (название, описание, длительность, **время начала** через `StartTimeField`, ответственный, повторение, дедлайн, приоритет, **напоминание** через `ReminderSelector`, **категория** через `CategoryField`). Повторение — через `RecurrenceEditor`.
- **edit_task_sheet.dart** — `showEditTaskSheet`: модальный bottom sheet редактирования задачи. Аналогично create, но предзаполнено из `Task` (включая `plannedTime` → `StartTimeField`). Для повторяющейся задачи сначала показывает scope-диалог, при `thisAndFollowing`/`all` показывает `RecurrenceEditor` (без переключателя) и сохраняет через `updateTemplate`. Для обычных задач показывает **`SubtaskEditor`** (подзадачи) и категорию через `CategoryField`. Подзадачи передаются в `SubtaskEditor` с `onReorder: _reorderSubtask` (drag&drop → `TaskSubtaskRepository.reorder`).

## Связи

- Основная фича, от которой зависят `today` и `scheduled`.
- `Task` — центральная доменная модель, импортируется всеми feature-слоями.
- `CreateTaskSheet` и `EditTaskSheet` вызываются из `TodayPage` и `ScheduledPage`.
- Использует `HouseholdMember` (из households) для виджетов назначения.
- `SupabaseTaskRepository` зависит от `SupabaseClient`.
- `DistributeTasksUseCase` зависит от `TaskRepository` + `HouseholdRepository`.
- Категории: `CategoryField`/`CategoryPicker` используют `TaskCategoryRepository` (читают через `context.read`).
- Подзадачи: `EditTaskSheet` использует `TaskSubtaskRepository` (загрузка + CRUD).
