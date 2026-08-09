import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native platform executor (macOS, iOS, Android, Linux) — file-based SQLite.
///
/// Returns a [LazyDatabase] — the file is only opened on the first query,
/// so construction itself needs no platform channels / I/O.
QueryExecutor? tryCreateDatabaseExecutor() {
  return LazyDatabase(_openConnection);
}

/// Resolves the application database file under the documents directory.
///
/// Separate top-level function (not a closure) so it can be covered directly
/// with a mocked [PathProviderPlatform] and does not capture any context.
Future<File> appDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'family_planner.db'));
}

Future<NativeDatabase> _openConnection() async {
  return NativeDatabase(await appDatabaseFile());
}
