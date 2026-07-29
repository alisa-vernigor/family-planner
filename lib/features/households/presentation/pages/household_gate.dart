import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_planner/features/households/presentation/cubit/household_cubit.dart';
import 'package:family_planner/features/households/presentation/cubit/household_state.dart';
import 'package:family_planner/features/households/presentation/widgets/app_shell.dart';
import 'package:family_planner/features/households/presentation/widgets/empty_shell.dart';

final class HouseholdGate extends StatefulWidget {
  const HouseholdGate({required this.currentMemberId, super.key});

  final String currentMemberId;

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

final class _HouseholdGateState extends State<HouseholdGate> {
  int _currentTab = 0;
  String? _selectedHouseholdId;
  final _prefsKeyTab = 'selected_tab';
  final _prefsKeyHousehold = 'selected_household_id';

  @override
  void initState() {
    super.initState();
    _restoreState();
    context.read<HouseholdCubit>().load();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentTab = prefs.getInt(_prefsKeyTab) ?? 0;
      _selectedHouseholdId = prefs.getString(_prefsKeyHousehold);
    });
  }

  Future<void> _saveTab(int index) async {
    _currentTab = index;
    (await SharedPreferences.getInstance()).setInt(_prefsKeyTab, index);
  }

  Future<void> _saveHousehold(String id) async {
    _selectedHouseholdId = id;
    (await SharedPreferences.getInstance()).setString(_prefsKeyHousehold, id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HouseholdCubit, HouseholdState>(
      builder: (context, state) {
        switch (state) {
          case HouseholdInitial():
          case HouseholdLoading():
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case HouseholdEmpty():
            _selectedHouseholdId = null;
            return EmptyShell(
              currentMemberId: widget.currentMemberId,
            );

          case HouseholdFailure(:final message):
            return Scaffold(
              appBar: AppBar(title: const Text('Семья')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          context.read<HouseholdCubit>().load();
                        },
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            );

          case HouseholdLoaded(:final households):
            final selected = _selectedHouseholdId;
            if (selected == null || !households.any((h) => h.id == selected)) {
              _selectedHouseholdId = households.first.id;
            }

            return AppShell(
              households: households,
              selectedHouseholdId: _selectedHouseholdId!,
              currentMemberId: widget.currentMemberId,
              currentTab: _currentTab,
              onTabChanged: (index) {
                setState(() {
                  _currentTab = index;
                });
                _saveTab(index);
              },
              onHouseholdChanged: (id) {
                setState(() {
                  _selectedHouseholdId = id;
                });
                _saveHousehold(id);
              },
            );
        }
      },
    );
  }
}

