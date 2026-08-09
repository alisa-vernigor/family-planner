import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_state.dart';
import 'package:family_planner/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_settings_page.dart';

/// Публичная страница профиля пользователя.
/// Показывает аватар, имя, био и статистику задач.
/// Доступна всем членам семьи, к которой принадлежит пользователь.
final class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.profileId,
    required this.displayName,
    this.viewerId,
    super.key,
  });

  final String profileId;
  final String displayName;

  /// ID текущего зрителя (того, кто открыл страницу). Если совпадает с
  /// [profileId] — показываем «Это вы» и кнопку редактирования.
  ///
  /// `null` — зритель неизвестен, страница ведёт себя как чужая.
  final String? viewerId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

final class _ProfilePageState extends State<ProfilePage> {
  ProfileStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final repository = context.read<ProfileRepository>();
      final stats = await repository.getStats(widget.profileId);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _refreshProfile() async {
    await _loadStats();
    if (mounted) {
      context.read<ProfileCubit>().load(widget.profileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ProfileRepository>();

    return BlocProvider(
      create: (_) => ProfileCubit(
        profileRepository: repository,
      )..load(widget.profileId),
      child: _ProfileScaffold(
        profileId: widget.profileId,
        displayName: widget.displayName,
        viewerId: widget.viewerId,
        stats: _stats,
        onRefresh: _refreshProfile,
      ),
    );
  }
}

final class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({
    required this.profileId,
    required this.displayName,
    this.viewerId,
    this.stats,
    required this.onRefresh,
  });

  final String profileId;
  final String displayName;
  final String? viewerId;
  final ProfileStats? stats;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cubitState = context.watch<ProfileCubit>().state;
    final isOwn = viewerId != null && cubitState is ProfileLoaded && cubitState.profile.id == viewerId;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileSettingsPage(profileId: profileId),
                  ),
                );
                onRefresh();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final profile = switch (state) {
                ProfileLoaded(:final profile) => profile,
                ProfileUpdateSuccess(:final profile) => profile,
                _ => null,
              };

              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  const SizedBox(height: 16),
                  AvatarWidget(profile: profile, radius: 56),
                  const SizedBox(height: 16),
                  Text(
                    profile.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  if (isOwn)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Это вы',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.bio,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Статистика',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (stats != null)
                    _StatsGrid(stats: stats!, cs: cs)
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.cs});

  final ProfileStats stats;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                value: '${stats.completedTasks}',
                label: 'Выполнено',
                color: cs.primary,
                cs: cs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_outlined,
                value: '${stats.totalAssigned}',
                label: 'Назначено',
                color: cs.secondary,
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                value: '${stats.completedThisWeek}',
                label: 'За неделю',
                color: cs.tertiary,
                cs: cs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.date_range,
                value: '${stats.completedThisMonth}',
                label: 'За месяц',
                color: cs.error,
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Всего назначено задач: ${stats.totalAssigned}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: stats.completionRate,
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(stats.completionRate * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cs,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}