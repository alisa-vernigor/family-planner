# Profile (lib/features/profile/)

Модуль профиля пользователя: просмотр/редактирование профиля, аватары (Supabase Storage), публичная страница со статистикой задач.

## Содержимое

### domain/

- **entities/user_profile.dart** — `UserProfile` (Equatable): id, displayName, avatarUrl, timezone, bio. `copyWith` с `clearAvatar`.
- **entities/profile_stats.dart** — `ProfileStats`: totalAssigned, completedTasks, completedThisMonth, completedThisWeek. `completionRate`.
- **repositories/profile_repository.dart** — контракт: `getProfile`, `updateProfile`, `uploadAvatar`, `removeAvatar`, `getStats`.
- **use_cases/** — 5 use cases, каждый оборачивает метод репозитория.

### data/

- **repositories/supabase_profile_repository.dart** — имплементация:
  - `getProfile` — SELECT profiles с RPC `get_profile_stats`.
  - `updateProfile` — UPDATE profiles.
  - `uploadAvatar` — upload в storage.bucket `avatars` → UPDATE avatar_url. Очистка кэша (`PaintingBinding`).
  - `removeAvatar` — удаление из storage, обнуление avatar_url.
  - `getStats` — RPC `get_profile_stats` (с проверкой: вызывающий и целевой профиль должны быть в одном household).
  - `_removeExistingAvatar` — удаление всех файлов в папке профиля.

### presentation/

- **cubit/profile_cubit.dart** — `ProfileCubit`: `load`, `updateProfile`, `uploadAvatar`, `removeAvatar`, `getStats`. Оптимистичные обновления.
- **cubit/profile_state.dart** — состояния: `Initial`, `Loading`, `Loaded`, `UpdateSuccess`, `AvatarUploading`, `Failure`.
- **pages/profile_page.dart** — `ProfilePage`: публичная страница профиля (доступна всем членам семьи). Аватар, имя, био (+ «Это вы» если свой), статистика (`_StatsGrid`: выполнено/назначено/за неделю/за месяц + прогресс-бар).
- **pages/profile_settings_page.dart** — `ProfileSettingsPage`: редактирование имени, био, загрузка/удаление аватара через `ImagePicker`. Превью pending-изменений. Кнопка «Сохранить» появляется только при наличии изменений.
- **widgets/avatar_widget.dart** — `AvatarWidget`: переиспользуемый аватар. Поддерживает `imageBytes` (pending preview), URL (NetworkImage), инициалы. 3 named конструктора: `AvatarWidget()`, `AvatarWidget.fromMember()`, `AvatarWidget.url()`.

## Связи

- `ProfileSettingsPage` открывается из `HouseholdGate` (popup menu).
- `ProfilePage` открывается из `HouseholdMembersPage.member.onTap` и из `TaskCard._AssigneeChip.onTap`.
- `AvatarWidget` используется в `assignee_picker.dart` (tasks feature).
- Зависит от `SupabaseClient`.
