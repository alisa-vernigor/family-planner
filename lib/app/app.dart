import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/households/domain/repositories/household_repository.dart';
import 'package:family_planner/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:family_planner/features/auth/domain/use_cases/get_current_user_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:family_planner/features/auth/domain/use_cases/sign_up_use_case.dart';
import 'package:family_planner/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:family_planner/features/auth/presentation/pages/auth_gate.dart';
import 'package:family_planner/features/households/data/repositories/supabase_household_repository.dart';
import 'package:family_planner/features/households/domain/use_cases/accept_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/create_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/decline_household_invitation_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/delete_household_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_my_households_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/get_pending_household_invitations_use_case.dart';
import 'package:family_planner/features/households/domain/use_cases/update_household_use_case.dart';
import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_invitations_cubit.dart';
import 'package:family_planner/features/tasks/data/repositories/supabase_task_repository.dart';
import 'package:family_planner/features/tasks/domain/repositories/task_repository.dart';

final class FamilyPlannerApp extends StatelessWidget {
  const FamilyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final authRepository = SupabaseAuthRepository(client: client);
    final householdRepository = SupabaseHouseholdRepository(client: client);
    final taskRepository = SupabaseTaskRepository(client: client);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>.value(value: taskRepository),
        RepositoryProvider<HouseholdRepository>.value(
          value: householdRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthCubit(
              getCurrentUserUseCase: GetCurrentUserUseCase(
                repository: authRepository,
              ),
              signInUseCase: SignInUseCase(repository: authRepository),
              signOutUseCase: SignOutUseCase(repository: authRepository),
              signUpUseCase: SignUpUseCase(repository: authRepository),
            ),
          ),
          BlocProvider(
            create: (_) => HouseholdCubit(
              createHouseholdUseCase: CreateHouseholdUseCase(
                repository: householdRepository,
              ),
              getMyHouseholdsUseCase: GetMyHouseholdsUseCase(
                repository: householdRepository,
              ),
              deleteHouseholdUseCase: DeleteHouseholdUseCase(
                repository: householdRepository,
              ),
              updateHouseholdUseCase: UpdateHouseholdUseCase(
                repository: householdRepository,
              ),
            ),
          ),
          BlocProvider(
            create: (_) => HouseholdInvitationsCubit(
              getPendingHouseholdInvitationsUseCase:
                  GetPendingHouseholdInvitationsUseCase(
                    repository: householdRepository,
                  ),
              acceptHouseholdInvitationUseCase:
                  AcceptHouseholdInvitationUseCase(
                    repository: householdRepository,
                  ),
              declineHouseholdInvitationUseCase:
                  DeclineHouseholdInvitationUseCase(
                    repository: householdRepository,
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Family Planner',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
