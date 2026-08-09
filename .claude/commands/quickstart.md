---
description: Сводка проекта (карта фич, конвенции, подводные камни)
---

Дай краткую сводку проекта Family Planner, чтобы быстро стартовать:

1. Коротко: стек, архитектура (Clean Architecture feature-first), DI, navigation.
2. Карта фич: где какой CLAUDE.md лежит (`lib/core`, `lib/app`, `lib/features/*`).
3. Конвенции, которые ломают компиляцию/тесты: `_Sentinel` в `copyWith`, фейки при изменении `TaskRepository`, процедура Drift-миграции.
4. Скоростные приёмы: `.g.dart` читать до компиляции; Drift-правки батчем + build_runner один раз; итерация через `dart analyze <файл>`; полные прогоны в финале. (Полный список — в `lib/core/CLAUDE.md` → «Скоростные приёмы».)
5. Повторяющиеся задачи (recurring): как устроено, где смотреть.
6. Импорт/экспорт задач: фича `lib/features/import_export/`, JSON-схема для нейросети — `docs/import_schema.json`, вход — меню «Ещё».
7. Частые команды: `/verify`, `/analyze-file`, `/drift-regenerate`, `/coverage`, `/import-export`.

Не делай изменений — только сводка.
