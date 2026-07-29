# Core (lib/core/)

Вспомогательные сервисы и конфигурация, общие для всех фич.

## Содержимое

- **config/supabase_config.dart** — `SupabaseConfig`: читает SUPABASE_URL и SUPABASE_PUBLISHABLE_KEY из `.env` файла или `--dart-define` (compile-time). Использует `flutter_dotenv`.
- **logging/app_logger.dart** — `AppLogger`: обёртка над `logger` package (debug/info/warning/error). Статические методы, единый экземпляр `Logger()`.
- **services/home_widget_service.dart** — `HomeWidgetService`: интеграция с Android Home Widget через `home_widget` package.
  - `initialize()` — регистрация `interactiveCallback` для фоновых коллбэков.
  - `syncTasks(tasks, currentMemberId, householdId)` — обновление данных виджета.
  - Сохранение Supabase-конфигурации и сессии в SharedPreferences (через `HomeWidget.saveWidgetData`).
  - `interactiveCallback` — фоновый изолят: обрабатывает нажатие на задачу в виджете (toggle complete/uncomplete). Восстанавливает Supabase-сессию из сохранённого JSON.

## Связи

- `app_bloc_observer.dart` использует `AppLogger`.
- `main.dart` вызывает `SupabaseConfig`, `AppLogger`, `HomeWidgetService.initialize()`.
- `HomeWidgetService` импортирует `Task` из tasks feature.
- Не зависит от других модулей приложения (кроме HomeWidgetService → tasks).
