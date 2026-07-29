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
  - Методы: `checkSession`, `signUp`, `signIn`, `signOut`.
  - Логирование через `AppLogger`. Обработка `AuthException` и непредвиденных ошибок.
- **cubit/auth_state.dart** — состояния: `AuthInitial`, `AuthLoading`, `AuthUnauthenticated`, `AuthAuthenticated`, `AuthEmailConfirmationRequired`, `AuthFailure`.
- **pages/auth_gate.dart** — корневой экран: по состоянию авторизации показывает либо спиннер → либо `AuthPage` / `EmailConfirmationPage` / `HouseholdGate`.
- **pages/auth_page.dart** — форма входа/регистрации: валидация полей, индикатор сложности пароля, переключение режимов.
- **pages/email_confirmation_page.dart** — экран «Подтвердите email» с кнопкой проверки сессии.
- **widgets/sign_out_button.dart** — простая кнопка выхода.

## Связи

- `AuthGate` — точка входа в приложение (`app.dart` → `MaterialApp.home`).
- `AuthCubit` создаётся в `app.dart` для всего приложения.
- Зависит от `SupabaseClient` (через `app.dart` Di).
- `auth_cubit.dart` напрямую импортирует `Supabase.instance.client` для `onAuthStateChange`.
- `households` feature: `AuthCubit.signOut` вызывается из `HouseholdGate` (popup menu).
