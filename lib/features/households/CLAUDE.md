# Households (lib/features/households/)

Модуль управления семьями (домохозяйствами): создание, просмотр участников, приглашения по email.

## Содержимое

### domain/

- **entities/household.dart** — `Household` (id, name).
- **entities/household_member.dart** — `HouseholdMember` (profileId, displayName, avatarUrl, role). `isOwner` если role == 'owner'.
- **entities/household_invitation.dart** — `HouseholdInvitation` (id, householdId, householdName, invitedByDisplayName, createdAt, expiresAt).
- **repositories/household_repository.dart** — абстрактный контракт: CRUD семьи, приглашения, участники.
- **use_cases/** — 10 use case classes, каждый оборачивает один метод репозитория.

### data/

- **repositories/supabase_household_repository.dart** — имплементация через RPC и прямые запросы Supabase:
  - `getMyHouseholds` — JOIN `household_members` → `households`.
  - `getMembers` — JOIN `household_members` → `profiles`.
  - `create`, `createInvitation`, `acceptInvitation`, `declineInvitation`, `leaveHousehold`, `removeMember`, `deleteHousehold`, `updateHousehold` — через RPC.
  - `getPendingInvitations` — прямой запрос с JOIN на `profiles` + отдельный запрос имён семей (N+1 fix).

### presentation/

- **cubit/household_cubit.dart** — `HouseholdCubit`: `load`, `refresh`, `create`, `delete`, `update`. `_postgrestMessage` для человекочитаемых ошибок.
- **cubit/household_state.dart** — состояния: `Initial`, `Loading`, `Empty`, `Loaded`, `Failure`.
- **cubit/household_invitations_cubit.dart** — `HouseholdInvitationsCubit`: `load`, `accept`, `decline`.
- **cubit/household_invitations_state.dart** — состояния: `Initial`, `Loading`, `Loaded`, `ActionInProgress`, `Failure`.
- **cubit/household_members_cubit.dart** — `HouseholdMembersCubit`: `load`, `inviteByEmail`, `leaveHousehold`, `removeMember`.
- **cubit/household_members_state.dart** — состояния: `Initial`, `Loading`, `Loaded`, `InvitationSending`, `InvitationSent`, `Failure`.
- **pages/household_gate.dart** — главный навигационный экран после авторизации. `_AppShell` с `IndexedStack` (TodayPage + ScheduledPage), `NavigationBar`, dropdown выбора семьи. `_EmptyShell` для случая без семей + приглашения.
- **pages/create_household_page.dart** — форма создания семьи.
- **pages/household_invitations_page.dart** — список приглашений с кнопками принять/отклонить.
- **pages/household_members_page.dart** — управление участниками: приглашение (для owner), удаление/выход.

## Связи

- `HouseholdGate` — корневой экран после аутентификации. Используется в `AuthGate`.
- `HouseholdCubit`, `HouseholdInvitationsCubit` создаются в `app.dart` на уровне приложения.
- `HouseholdMembersCubit` создаётся локально в `HouseholdMembersPage`.
- Зависит от `SupabaseClient` (через `SupabaseHouseholdRepository`).
- Зависит от `AuthCubit` для выхода (sign out).
- Использует `TodayPage`, `ScheduledPage`, `ProfileSettingsPage`, `ProfilePage` из других фич.
