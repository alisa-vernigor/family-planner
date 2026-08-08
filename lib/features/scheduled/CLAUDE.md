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
  - **Поиск** по названию/описанию (TextField `task_search_field`, case-insensitive, статический `ScheduledPage.matchesSearchQuery` для тестируемости). Применяется поверх фильтра, во всех режимах (список/матрица/календарь).
  - Сортировка через `SortSelector`.
  - Три режима отображения (`_ViewMode`): список (с группировкой по дате), `EisenhowerMatrixView`, `CalendarView`.
  - `_ScheduledTaskCard` — карточка для списка (отличается от `TaskCard` — без свайпов, компактнее). Меню: редактировать, перенести, дублировать, пауза серии, **пропустить** (`onSkip`).
  - `_FilterChip` — кастомный фильтр-чип.
  - FAB создания задачи.
  - Категории: страница загружает их (`TaskCategoryRepository.getForHousehold`) в `_categoriesById` и передаёт в `ScheduledTaskCard.category` (чип).
- **widgets/calendar_view.dart** — `CalendarView`: календарный режим через пакет `table_calendar`.
  - **Три режима** (`_CalendarMode`): «Месяц» (сетка `TableCalendar` с полосками задач), «Неделя» и «День» (временная шкала `TimeScaleView` с часами). Переключение — `SegmentedButton` сверху (встроенный `formatButton` скрыт).
  - Месячная сетка `TableCalendar<Task>` (переключатель «Месяц/Неделя» в шапке через `availableCalendarFormats` + `onFormatChanged`), старт недели с понедельника, русская локаль (`ru_RU`).
  - **Полоски задач в ячейках (как события Google Calendar)**: вместо точек-маркеров в каждой ячейке месяца — цветные полоски `_DayTaskBar` (цвет = категория через `_markerColor`), до 2 полосок; при большем количестве — «+N ещё». Рисуются внутри `_buildDayCell` (Column: номер + полоски), `markerBuilder` возвращает `SizedBox.shrink` (точки не нужны). Высота ячейки в месячном виде ограничена родителем (~52px) — полоски компактные (13px).
  - Задачи за пределами видимого месяца не скрываются.
  - Под сеткой — список задач выбранного дня (с зачёркиванием выполненных) + заголовок «d MMMM yyyy — N задач».
  - **Drag & drop перенос**: длинное нажатие на карточку в списке дня (`LongPressDraggable<Task>`) → перетащить на день в сетке (`DragTarget<Task>` через `calendarBuilders`). Выполненные задачи не переносятся. Стриница передаёт `onRescheduleToDay` → `_rescheduleTaskToDay` (без диалога; серия переносится целиком через `RescheduleTaskUseCase`).
  - **Авто-листание при перетаскивании**: `_edgeDirection` (край 64px) → `_startAutoScroll`/`_stopAutoScroll` (`Timer.periodic` 300мс → `PageController.nextPage/previousPage` через `_pageController` из `onCalendarCreated`). Таймер останавливается в `onDragStarted`/`onDragEnd`/`onDraggableCanceled` и в `dispose`.
  - Переиспользует те же колбэки, что и список: edit/delete/assign/pin/reschedule/duplicate/complete/uncomplete/create + **skip** (`onSkip`, пункт «Пропустить»).
  - Пустой день — состояние с кнопкой «Создать задачу».
- **widgets/time_scale_view.dart** — `TimeScaleView` (StatefulWidget): временная шкала задач (неделя/день) с часами, как события Google Calendar.
  - `hourHeight = 52px`, гуттер подписей часов 44px. В недельном режиме колонки дней растягиваются на всю ширину (мин. `kMinWeekColumnWidth = 48px`); на узких экранах — горизонтальный скролл.
  - **Шапка дней**: в недельном режиме над шкалой — дни недели с датами (пн…вс), сегодня подсвечен кругом.
  - **Синхронный скролл**: шапка дней, ряд «Весь день» и шкала — три горизонтальных `ScrollController`, связанных слушателями (`jumpTo` при расхождении > 0.5px), чтобы столбцы не разъезжались.
  - Задачи с `Task.plannedTime` рисуются блоками в сетке часов: вертикальная позиция = время начала, высота = `estimatedDurationMinutes` (мин. 36px), колонки пересекающихся по времени блоков как в Google Calendar (`_layoutDayBlocks` — разбиение интервалов по колонкам). В блоках ниже 44px заголовок — в 1 строку, выше — в 2.
  - Задачи без времени — полоски `_AllDayChip` в ряду «Весь день» над шкалой.
  - В колонке «сегодня» — красная линия текущего времени (`_nowIndicator`) и подложка.
  - Блоки кликабельны (редактирование), чекбокс внутри — complete/uncomplete.
  - Цвет блока = категория (`_markerColor`).
  - Навигация `<`/`>` в шапке — на день/неделю.

## Связи

- Вложена в `HouseholdGate` через `IndexedStack` (таб «Запланированные»).
- Использует `TaskRepository`, `HouseholdRepository`, `Supabase.instance.client` (realtime), `TaskCategoryRepository` (для чипов категорий).
- Использует `CreateTaskSheet`, `EditTaskSheet`, `EisenhowerMatrixView`, `AssigneePicker`, `SortSelector` из `tasks` feature.
- Зависит от пакета `table_calendar` (только `CalendarView`).
- В отличие от `TodayPage`, не имеет `TaskCompletionCubit`/`TaskActionsCubit` — обрабатывает complete/uncomplete/delete прямо на странице (instant via cubit + repository).
