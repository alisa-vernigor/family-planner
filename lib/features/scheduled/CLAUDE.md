# Scheduled (lib/features/scheduled/)

Экран «Запланированные» — все невыполненные задачи на будущие даты с группировкой по дням, матрицей Эйзенхауэра, фильтрацией.

## Содержимое

### presentation/

- **cubit/scheduled_tasks_cubit.dart** — `ScheduledTasksCubit`:
  - `load(householdId)` — полная загрузка всех невыполненных задач (на 6 месяцев вперёд).
  - `refresh(householdId)` — тихая перезагрузка.
  - `replaceTask`, `removeTask`, `confirmDelete`, `cancelDelete` — оптимистичные обновления.
  - Загружает задачи + участников параллельно через `Future.wait`.
- **cubit/scheduled_tasks_state.dart** — состояния: `Initial`, `Loading`, `Loaded` (tasks + members), `Failure`.
- **pages/scheduled_page.dart** — `ScheduledPage`:
  - `_ScheduledView`: Realtime-подписка на `task_occurrences` (дебounce 1.5с).
  - Фильтры: «Все», «Мои», «Без назначения».
  - Сортировка через `SortSelector`.
  - Два режима отображения: список (с группировкой по дате) и `EisenhowerMatrixView`.
  - `_ScheduledTaskCard` — карточка для списка (отличается от `TaskCard` — без свайпов, компактнее).
  - `_FilterChip` — кастомный фильтр-чип.
  - FAB создания задачи.

## Связи

- Вложена в `HouseholdGate` через `IndexedStack` (таб «Запланированные»).
- Использует `TaskRepository`, `HouseholdRepository`, `Supabase.instance.client` (realtime).
- Использует `CreateTaskSheet`, `EditTaskSheet`, `EisenhowerMatrixView`, `AssigneePicker`, `SortSelector` из `tasks` feature.
- В отличие от `TodayPage`, не имеет `TaskCompletionCubit`/`TaskActionsCubit` — обрабатывает complete/uncomplete/delete прямо на странице (instant via cubit + repository).
