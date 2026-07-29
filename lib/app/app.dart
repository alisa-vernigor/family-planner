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
import 'package:family_planner/features/tasks/data/repositories/supabase_task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';

import 'package:family_planner/app/theme.dart';

final class FamilyPlannerApp extends StatelessWidget {
  const FamilyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final authRepository = SupabaseAuthRepository(client: client);
    final householdRepository = SupabaseHouseholdRepository(client: client);
    final taskRepository = SupabaseTaskRepository(client: client);
    final profileRepository = SupabaseProfileRepository(client: client);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>.value(value: taskRepository),
        RepositoryProvider<HouseholdRepository>.value(
          value: householdRepository,
        ),
        RepositoryProvider<ProfileRepository>.value(
          value: profileRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthCubit(
              authRepository: authRepository,
            ),
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
