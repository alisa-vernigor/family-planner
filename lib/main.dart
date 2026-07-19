import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'core/config/supabase_config.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = AppBlocObserver();

  if (SupabaseConfig.url.isEmpty || SupabaseConfig.publishableKey.isEmpty) {
    throw StateError(
      'Не заданы SUPABASE_URL или SUPABASE_PUBLISHABLE_KEY. '
      'Запускай приложение через --dart-define.',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  AppLogger.info('Supabase инициализирован');
  AppLogger.info('Запуск Family Planner');

  runApp(const FamilyPlannerApp());
}
