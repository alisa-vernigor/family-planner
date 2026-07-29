/// Приоритет задачи по матрице Эйзенхауэра.
///
///   Срочно          | Не срочно
/// ──────────────────┼──────────────────
/// 1 — Важно         | 2 — Важно
/// 3 — Не важно      | 4 — Не важно
///
/// Значение в БД: priority INT (1–4), null = 4 (по умолчанию).
enum EisenhowerPriority {
  urgentImportant(1, 'Срочно и важно'),
  notUrgentImportant(2, 'Не срочно, но важно'),
  urgentNotImportant(3, 'Срочно, но не важно'),
  notUrgentNotImportant(4, 'Не срочно и не важно');

  const EisenhowerPriority(this.value, this.label);

  final int value;
  final String label;

  static EisenhowerPriority? fromValue(int? value) {
    return switch (value) {
      1 => urgentImportant,
      2 => notUrgentImportant,
      3 => urgentNotImportant,
      4 => notUrgentNotImportant,
      _ => null,
    };
  }
}
