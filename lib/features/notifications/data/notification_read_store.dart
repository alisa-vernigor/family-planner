import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище read-статуса уведомлений.
///
/// Read-статус — чисто локальное состояние UI: на сервере не существует
/// «прочитано/непрочитано» (в таблицах нет такой колонки). Храним его
/// в SharedPreferences — это дешевле Drift-таблицы (не нужен schemaVersion++,
/// build_runner и т.д.) и не требует синхронизации между устройствами.
///
/// Непрочитанными считаются все события, кроме «прочитанных вручную».
/// Декодер восстанавливает ключи событий (как в [NotificationItem.id]),
/// а старые/несуществующие события отфильтровываются при сборке ленты.
final class NotificationReadStore {
  static const _prefsKey = 'read_notifications';

  Future<Set<String>> loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw.toSet();
  }

  Future<void> markAllRead(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = await loadReadIds();
    merged.addAll(ids);
    await prefs.setStringList(_prefsKey, merged.toList()..sort());
  }
}
