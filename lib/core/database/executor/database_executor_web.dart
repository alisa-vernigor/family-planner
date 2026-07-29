import 'package:drift/drift.dart';

/// Web fallback — не используем SQLite, только онлайн-режим.
/// Возвращаем null, и main() создаст AppDatabase как no-op.
QueryExecutor? tryCreateDatabaseExecutor() => null;
