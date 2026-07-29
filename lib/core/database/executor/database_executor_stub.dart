import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Creates a native SQLite database executor (macOS, iOS, Android, Linux).
QueryExecutor createDatabaseExecutor() {
  return _NativeExecutor();
}

final class _NativeExecutor extends LazyDatabase {
  _NativeExecutor() : super(_openConnection);

  static Future<NativeDatabase> _openConnection() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'family_planner.db'));
    return NativeDatabase(file);
  }
}
