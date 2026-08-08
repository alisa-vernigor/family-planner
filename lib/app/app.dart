import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:family_planner/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/pages/auth_gate.dart';
import 'package:family_planner/features/households/data/repositories/supabase_household_repository.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/notifications/data/repositories/supabase_notifications_repository.dart';
import 'package:family_planner/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/drift_task_category_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/drift_task_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/drift_task_subtask_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/supabase_task_category_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/supabase_task_repository.dart';
import 'package:family_planner/features/tasks/data/repositories/supabase_task_subtask_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_category_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_subtask_repository.dart';
import 'package:family_planner/core/database/app_database.dart';
import 'package:family_planner/core/services/connectivity_service.dart';
import 'package:family_planner/core/sync/sync_cubit.dart';
import 'package:family_planner/core/sync/sync_processor.dart';

import 'package:family_planner/app/theme.dart';

final class FamilyPlannerApp extends StatelessWidget {
  const FamilyPlannerApp({
    this.database,
    required this.connectivityService,
    this.syncProcessor,
    super.key,
  });

  /// null на web (online-only), инициализирован на нативных платформах.
  final AppDatabase? database;
  final ConnectivityService connectivityService;
  final SyncProcessor? syncProcessor;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    // ── Repositories ──
    final authRepository = SupabaseAuthRepository(client: client);
    final householdRepository = SupabaseHouseholdRepository(client: client);

    // Если есть SQLite — используем DriftTaskRepository (offline-first),
    // иначе — SupabaseTaskRepository (online-only, как было раньше).
    final TaskRepository taskRepository;
    if (database != null) {
      taskRepository = DriftTaskRepository(
        database: database!,
        supabaseClient: client,
        connectivityService: connectivityService,
      );
    } else {
      taskRepository = SupabaseTaskRepository(client: client);
    }

    // Подзадачи: offline-first через Drift на нативных, напрямую на web.
    final TaskSubtaskRepository subtaskRepository;
    if (database != null) {
      subtaskRepository = DriftTaskSubtaskRepository(
        database: database!,
        supabaseClient: client,
        connectivityService: connectivityService,
      );
    } else {
      subtaskRepository = SupabaseTaskSubtaskRepository(client: client);
    }

    // Категории: справочные данные, кэшируются в Drift, пишутся напрямую.
    final TaskCategoryRepository categoryRepository;
    if (database != null) {
      categoryRepository = DriftTaskCategoryRepository(
        database: database!,
        supabaseClient: client,
        connectivityService: connectivityService,
      );
    } else {
      categoryRepository = SupabaseTaskCategoryRepository(client: client);
    }

    final profileRepository = SupabaseProfileRepository(client: client);
    final notificationsRepository = SupabaseNotificationsRepository(
      client: client,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>.value(value: taskRepository),
        RepositoryProvider<TaskSubtaskRepository>.value(
          value: subtaskRepository,
        ),
        RepositoryProvider<TaskCategoryRepository>.value(
          value: categoryRepository,
        ),
        RepositoryProvider<HouseholdRepository>.value(
          value: householdRepository,
        ),
        RepositoryProvider<ProfileRepository>.value(
          value: profileRepository,
        ),
        RepositoryProvider<NotificationsRepository>.value(
          value: notificationsRepository,
        ),
        RepositoryProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
        if (database != null)
          RepositoryProvider<AppDatabase>.value(value: database!),
        if (syncProcessor != null)
          RepositoryProvider<SyncProcessor>.value(value: syncProcessor!),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthCubit(authRepository: authRepository),
          ),
          BlocProvider(
            create: (_) => HouseholdCubit(
              householdRepository: householdRepository,
            ),
          ),
          BlocProvider(
            create: (_) => HouseholdInvitationsCubit(
              householdRepository: householdRepository,
            ),
          ),
          BlocProvider(
            create: (_) => SyncCubit(
              connectivityService: connectivityService,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Family Planner',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          home: const AuthGate(),
          builder: (context, child) {
            ErrorWidget.builder = (details) {
              return Material(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48,
                          color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        const Text('Произошла ошибка. Попробуйте перезапустить приложение.'),
                      ],
                    ),
                  ),
                ),
              );
            };
            return child!;
          },
        ),
      ),
    );
  }
}
