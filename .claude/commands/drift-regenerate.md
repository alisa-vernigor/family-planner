---
description: Перегенерировать Drift-код (build_runner)
---

Запусти `dart run build_runner build` для регенерации `.g.dart` после изменения Drift-таблиц.

Затем проверь `dart analyze lib` — если Companion'ы не обновились, исправь их (см. процедуру Drift-миграции в `lib/core/CLAUDE.md`).
