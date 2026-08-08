# Notifications (lib/features/notifications/)

Центр уведомлений / inbox — лента активности семьи.

## Содержимое

### domain/

- **entities/notification_item.dart** — `NotificationItem` (Equatable): одно событие ленты. Поля: id (уникальный ключ `task:<id>:<kind>` / `invitation:<id>`), kind (`NotificationKind`: taskAssigned / taskCompleted / taskSkipped / invitation), actorId, actorName, title, subtitle, occurredAt, taskId?, taskStatus?, invitationId?, invitationStatus?, householdId?. `copyWith(taskStatus:, invitationStatus:)`.
- **repositories/notifications_repository.dart** — абстрактный контракт: `getActivityFeed({householdId})` → `List<NotificationItem>` (отсортировано по времени, новые сверху), `markAllRead()` (no-op на сервере — read-статус только локальный).

### data/

- **repositories/supabase_notifications_repository.dart** — `SupabaseNotificationsRepository`: собирает ленту из **существующих таблиц** (никаких новых RPC/таблиц):
  - `task_occurrences` (окно 30 дней, `updated_at >= now-30d`):
    - **назначена мне другим участником** (`assigned_member_id == me && created_by != me`);
    - **выполнена/пропущена другим участником** (`status in [completed, skipped] && created_by != me`).
  - `household_invitations` (входящие, `invited_profile_id == me`).
  - Имя актора — вложенный select `profiles!task_occurrences_created_by_fkey(display_name)` / `profiles!household_invitations_invited_by_profile_id_fkey(display_name)`.
  - `markAllRead` — no-op (read-статус живёт только локально).
- **notification_read_store.dart** — `NotificationReadStore`: read-статус уведомлений в **SharedPreferences** (ключ `read_notifications`, `List<String>`). Почему не Drift: на сервере нет «прочитано/непрочитано», поэтому синхронизировать нечего; SharedPreferences дешевле (без schemaVersion++ / build_runner).

### presentation/

- **cubit/notifications_cubit.dart** — `AppNotificationsCubit`: `load`, `refresh` (pull-to-refresh/смена таба, читает read-статус из стора), `markAllRead`, `removeItem` (после принятия/отклонения приглашения), `unreadCount` (getter). Опциональный параметр `notifications` — инъекция списка для тестов/превью.
- **cubit/notifications_state.dart** — состояния: `Initial`, `Loading`, `Loaded` (items + readIds), `Failure`.
- **pages/notifications_page.dart** — `NotificationsPage`: список уведомлений, pull-to-refresh, «Прочитать всё» (AppBar action), пустое состояние. Тап по карточке: задача → `showEditTaskSheet` (загружает через `TaskRepository.getAllPending`); приглашение → `HouseholdInvitationsPage`. В карточке приглашения — кнопки «Принять» (через `HouseholdInvitationsCubit.accept` + перезагрузка `HouseholdCubit`) / «Отклонить». **Cubit НЕ создаёт** — получает из AppShell (BlocProvider выше).

## Связи

- **Cubit создаётся на уровне AppShell** (`BlocProvider` в `AppShell.build`), чтобы бейдж в NavigationBar видел `unreadCount`. `NotificationsPage` — только подписчик.
- Репозиторий регистрируется в `app.dart` (`RepositoryProvider<NotificationsRepository>`).
- Зависит от `HouseholdInvitationsCubit` / `HouseholdCubit` (для принятия приглашения), `TaskRepository` (открытие задачи), `SharedPreferences`.
- Таб «Уведомления» — 3-й в `NavigationBar` AppShell; при переключении на него вызывается `refresh()`.
- НЕ использует Drift/SyncQueue (read-статус локальный, данных на сервере нет).

## Оффлайн

- Лента требует сети (собирается на сервере из task_occurrences + household_invitations). Read-статус работает офлайн (SharedPreferences), но на новых событиях офлайн-кэша ленты нет — при возвращении сети данные подтягиваются.
