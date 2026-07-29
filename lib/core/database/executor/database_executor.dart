/// На нативных платформах — NativeDatabase (drift/native),
/// на web — заглушка (WASM SQLite не подключён).
export 'database_executor_io.dart'
    if (dart.library.js) 'database_executor_web.dart';
