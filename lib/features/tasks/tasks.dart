/// Tasks feature — public API.
///
/// Единая точка импорта для всех внешних фич (today, scheduled, app).
/// Не включает presentation/cubit (cubit'ы создаются через context,
/// их не нужно импортировать явно) и presentation/widgets
/// (используются как show-импорты).

// domain
export 'domain/entities/create_task_params.dart';
export 'domain/entities/eisenhower_priority.dart';
export 'domain/entities/task.dart';
export 'domain/entities/task_recurrence.dart';
export 'domain/entities/task_sort_option.dart';
export 'domain/entities/task_status.dart';
export 'domain/repositories/task_repository.dart';
export 'domain/services/task_schedule.dart';

// use cases
export 'domain/use_cases/assign_task_use_case.dart';
export 'domain/use_cases/complete_task_use_case.dart';
export 'domain/use_cases/create_task_use_case.dart';
export 'domain/use_cases/distribute_tasks_use_case.dart';
export 'domain/use_cases/uncomplete_task_use_case.dart';
export 'domain/use_cases/unpin_task_use_case.dart';
export 'domain/use_cases/update_task_priority_use_case.dart';
export 'domain/use_cases/update_task_use_case.dart';

// states (sealed — нужны для pattern matching)
export 'presentation/cubit/create_task_state.dart';
export 'presentation/cubit/task_action_state.dart';
export 'presentation/cubit/task_completion_state.dart';
export 'presentation/cubit/update_task_state.dart';

// cubits
export 'presentation/cubit/create_task_cubit.dart';
export 'presentation/cubit/task_actions_cubit.dart';
export 'presentation/cubit/task_completion_cubit.dart';
export 'presentation/cubit/update_task_cubit.dart';

// pages (функции showCreateTaskSheet / showEditTaskSheet)
export 'presentation/pages/create_task_sheet.dart';
export 'presentation/pages/edit_task_sheet.dart';

// виджеты (публичные)
export 'presentation/widgets/assignee_picker.dart';
export 'presentation/widgets/eisenhower_matrix_view.dart';
export 'presentation/widgets/filter_chip.dart';
export 'presentation/widgets/priority_selector.dart';
export 'presentation/widgets/sort_selector.dart';
export 'presentation/widgets/task_card.dart';
