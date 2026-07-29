import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'core/config/supabase_config.dart';
import 'core/database/app_database.dart';
import 'core/database/executor/database_executor.dart';
import 'core/logging/app_logger.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/sync/sync_processor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = AppBlocObserver();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    AppLogger.warning('Не удалось загрузить .env файл: $e');
  }

  if (SupabaseConfig.url.isEmpty || SupabaseConfig.publishableKey.isEmpty) {
    throw StateError(
      'Не заданы SUPABASE_URL или SUPABASE_PUBLISHABLE_KEY. '
      'Убедитесь, что файл .env создан в корне проекта и добавлен в pubspec.yaml в секцию assets.',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await HomeWidgetService.initialize();

  // ── Offline-first infrastructure ─────────────────────
  // На нативных платформах (macOS/iOS/Android) создаём SQLite.
  // На web — возвращаем null и работаем в online-only режиме.
  final executor = tryCreateDatabaseExecutor();
  final database = executor != null ? AppDatabase(executor) : null;
  final connectivityService = ConnectivityService();

  final SyncProcessor? syncProcessor;
  if (database != null) {
    syncProcessor = SyncProcessor(
      queueDao: database.syncQueueDao,
      supabaseClient: Supabase.instance.client,
      connectivityService: connectivityService,
    );

    // Auto-sync queue when coming online
    connectivityService.isOnline.listen((online) {
      if (online) {
        syncProcessor!.processPending().then((result) {
          if (!result.isEmpty) {
            AppLogger.info('Auto-sync complete: $result');
          }
        }).catchError((e) {
          AppLogger.warning('Auto-sync failed: $e');
        });
      }
    });
  } else {
    syncProcessor = null;
  }

  AppLogger.info('Supabase инициализирован');
  AppLogger.info('Запуск Family Planner');

  runApp(FamilyPlannerApp(
    database: database,
    connectivityService: connectivityService,
    syncProcessor: syncProcessor,
  ));
}
