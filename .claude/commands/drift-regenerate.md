---
description: Перегенерировать Drift-код (build_runner)
---

Запусти `dart run build_runner build` для регенерации `.g.dart` после изменения Drift-таблиц.

Затем проверь `dart analyze lib` — если Companion'ы не обновились, исправь их (см. процедуру Drift-миграции в `lib/core/CLAUDE.md`).

> **Скорость:** build_runner медленный (минуты). Делай ВСЕ Drift-правки батчем и запускай его ОДИН раз в конце. Перед правкой drift-репозитория прочитай нужный фрагмент `app_database.g.dart` ДО компиляции — там видны row-классы, семантика `copyWith` (nullable-колонки = `Value<T>`) и имена DAO-методов.
