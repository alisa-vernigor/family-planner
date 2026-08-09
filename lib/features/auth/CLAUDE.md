# Auth (lib/features/auth/)

Модуль аутентификации — вход/регистрация/выход из аккаунта через Supabase Auth.

## Содержимое

### domain/

- **entities/app_user.dart** — `AppUser` (id, email). Базовая модель аутентифицированного пользователя.
- **repositories/auth_repository.dart** — абстрактный контракт `AuthRepository`: `currentUser`, `signUp`, `signIn`, `signOut`.
- **use_cases/sign_in_use_case.dart** — валидации нет, делегирует `AuthRepository.signIn`.
- **use_cases/sign_up_use_case.dart** — делегирует `AuthRepository.signUp`.
- **use_cases/sign_out_use_case.dart** — делегирует `AuthRepository.signOut`.
- **use_cases/get_current_user_use_case.dart** — синхронный геттер `currentUser`.

### data/

- **repositories/supabase_auth_repository.dart** — имплементация `AuthRepository` через `SupabaseClient.auth`. Содержит `AuthUserNotReturnedException`.

### presentation/

- **cubit/auth_cubit.dart** — `AuthCubit`: слушает `onAuthStateChange`, управляет `AuthState`.
  - Методы: `checkSession`, `signUp`, `signIn`, `signOut`, `sendPasswordReset`, `updatePassword`, `showForgotPassword`, `showSignIn`.
  - Логирование через `AppLogger`. Обработка `AuthException` и непредвиденных ошибок.
- **cubit/auth_state.dart** — состояния: `AuthInitial`, `AuthLoading`, `AuthUnauthenticated`, `AuthAuthenticated`, `AuthEmailConfirmationRequired`, `AuthFailure`, `AuthForgotPassword`, `AuthPasswordResetSent`, `AuthPasswordResetReady`, `AuthPasswordResetSuccess`.
- **pages/auth_gate.dart** — корневой экран: по состоянию авторизации показывает либо спиннер → либо `AuthPage` / `EmailConfirmationPage` / `HouseholdGate`.
- **pages/auth_page.dart** — форма входа/регистрации: валидация полей, индикатор силы пароля (пересчитывается по `onChanged`), переключение режимов.
- **pages/email_confirmation_page.dart** — экран «Подтвердите email» с кнопкой проверки сессии.
- **pages/forgot_password_page.dart** — форма запроса сброса пароля (`sendPasswordReset` с `redirectTo: familyplanner://auth/callback`).
- **pages/reset_password_page.dart** — форма нового пароля (`updatePassword`); индикатор силы + подтверждение пароля.
- **pages/password_reset_sent_page.dart** / **pages/password_reset_success_page.dart** — информационные экраны.
- **widgets/sign_out_button.dart** — простая кнопка выхода.

### Тесты auth pages

- `test/features/auth/presentation/pages/auth_gate_test.dart` — маршрутизация всех состояний (Loading/Unauthenticated/Failure/ForgotPassword/PasswordResetSent/PasswordResetReady/PasswordResetSuccess/EmailConfirmationRequired/Authenticated). Для Authenticated поднимает полный стек репозиториев (`HouseholdRepository`, `TaskRepository`, категории, подзадачи, notifications, connectivity) → AppShell. Примечание: событие auth-листенера (`passwordRecovery`) доставляется через `tester.runAsync` + двойной `pump`, т.к. `emit` вне дерева требует лишнего кадра.
- `test/features/auth/presentation/pages/auth_page_test.dart` — валидация, переключение режима, сила пароля (onChanged), скрытие/показ пароля, submit через кнопку и `onFieldSubmitted`.
- `test/features/auth/presentation/pages/forgot_password_page_test.dart`, `reset_password_page_test.dart` — валидация, `sendPasswordReset`/`updatePassword`, состояния Failure/Loading, сила пароля.
- `test/features/auth/presentation/pages/email_confirmation_page_test.dart`, `password_reset_sent_page_test.dart`, `password_reset_success_page_test.dart` — контент и действия.

## Связи

- `AuthGate` — точка входа в приложение (`app.dart` → `MaterialApp.home`).
- `AuthCubit` создаётся в `app.dart` для всего приложения.
- Зависит от `SupabaseClient` (через `app.dart` Di).
- `auth_cubit.dart` напрямую импортирует `Supabase.instance.client` для `onAuthStateChange`.
- `households` feature: `AuthCubit.signOut` вызывается из `HouseholdGate` (popup menu).
