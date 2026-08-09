---
description: Сводка по импорту/экспорту задач + JSON-схема для нейросети
---

Кратко: как устроен импорт/экспорт задач в JSON и где взять схему для нейросети.

1. **Карта фичи**: `lib/features/import_export/CLAUDE.md` (формат, файлы, ограничения).
2. **JSON-схема для нейросети**: `docs/import_schema.json` (JSON Schema draft-07). Дай её модели, чтобы она сгенерила задачи в правильном формате.
3. **Формат**: `{version, tasks:[{title, description?, date?, time?, deadline?, duration_minutes?, priority? (1–4), assignee?, category?, subtasks?}]}`.
   - `date` без значения → сегодня; `assignee`/`category` — по именам (id в JSON не попадают).
   - Импорт **только онлайн** (подзадачи цепляются к серверному id задачи).
4. **UI**: меню «Ещё» в `AppShell` → `ImportExportPage`. После импорта `AppShell` пересоздаёт табы (инкремент `_dataVersion` в `ValueKey`).

Не делай изменений — только сводка + выведи путь к схеме.
