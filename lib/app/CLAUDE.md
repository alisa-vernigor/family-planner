# App (lib/app/)

Конфигурация приложения: точка входа Flutter, Material-тема, глобальный BLoC observer.

## Содержимое

- **app.dart** — `FamilyPlannerApp` (StatelessWidget): инициализация зависимостей в `MultiRepositoryProvider`/`MultiBlocProvider`, MaterialApp с русской локализацией, кастомный `ErrorWidget.builder`.
  - Репозитории: `SupabaseAuthRepository`, `SupabaseHouseholdRepository`, `SupabaseProfileRepository`, а также `TaskRepository` — **динамический выбор**: `DriftTaskRepository` (offline-first, если `database != null`) или `SupabaseTaskRepository` (online-only, web).
  - Подзадачи/категории: `TaskSubtaskRepository` и `TaskCategoryRepository` — тоже динамический выбор (Drift ↔ Supabase) по `database != null`. Провайдеры: `RepositoryProvider<TaskSubtaskRepository>`, `RepositoryProvider<TaskCategoryRepository>`.
  - BLoC'ы: `AuthCubit`, `HouseholdCubit`, `HouseholdInvitationsCubit`, `SyncCubit`.
  - Тема: `AppTheme.light()` / `AppTheme.dark()` (ThemeMode.system).
  - Home: `AuthGate`.
- **theme.dart** — `AppTheme`: Material 3 тема с кастомным seed-цветом (#6759A0). Стилизованные AppBar, Card, InputDecoration, Button, NavigationBar, SnackBar, FAB, Dialog, Chip, Divider, PopupMenu.
- **app_bloc_observer.dart** — `AppBlocObserver`: логирование создания/изменения/ошибок/закрытия BLoC'ов через `AppLogger`. В production onChange не логируется.

## Связи

- Импортируется из `main.dart`.
- Импортирует repositories и cubits всех фич (auth, households, tasks, profile).
- Связывает все фичи через DI (RepositoryProvider + BlocProvider).
