# Today (lib/features/today/)

Экран «Сегодня» — задачи на текущий день с группировкой, batch-операциями, сортировкой, авто-распределением.

## Содержимое

### presentation/

- **cubit/today_tasks_cubit.dart** — `TodayTasksCubit`:
  - `load(householdId, day)` — полная загрузка со спиннером.
  - `refresh(householdId, day)` — тихая перезагрузка без спиннера (для realtime/reload).
  - `distribute(householdId, day)` — авто-распределение задач.
  - `replaceTask`, `removeTask`, `confirmDelete`, `cancelDelete` — оптимистичные обновления.
  - После загрузки синхронизирует виджет через `HomeWidgetService.syncTasks`.
  - Загружает задачи + участников параллельно через `Future.wait`.
- **cubit/today_tasks_state.dart** — состояния: `Initial`, `Loading`, `Loaded` (tasks + members), `Failure`.
- **pages/today_page.dart** — `TodayPage`:
  - `MultiBlocProvider` (3 cubit'а: `TodayTasksCubit`, `TaskCompletionCubit`, `TaskActionsCubit`).
  - `_TodayView`: Realtime-подписка на `task_occurrences` через Supabase (дебounce 1.5с).
  - Группировка задач: «Мои задачи», «Задачи семьи», «Неназначенные».
  - Batch-режим: long press → выбор нескольких задач → batch complete.
  - Swipe-to-complete/uncomplete/delete для каждой задачи.
  - FAB: создание задачи + авто-распределение.
  - `_TaskListView` — список с разделами и `SortSelector`.
  - `_SectionHeader` — заголовок секции с счётчиком.
  - Категории: страница загружает их (`TaskCategoryRepository.getForHousehold`) в `_categoriesById` и передаёт в `TaskListView` → `TaskCard.category` (чип).

## Связи

- Вложена в `HouseholdGate` через `IndexedStack` (таб «Сегодня»).
- Использует `TaskRepository` (через use cases), `HouseholdRepository`, `Supabase.instance.client` (realtime), `TaskCategoryRepository` (для чипов категорий).
- Использует `CreateTaskSheet`, `EditTaskSheet`, `TaskCard`, `AssigneePicker`, `SortSelector` из `tasks` feature.
- `TodayTasksCubit` использует `TaskSchedule` (services).
