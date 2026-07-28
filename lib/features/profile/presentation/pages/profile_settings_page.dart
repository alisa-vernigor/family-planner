import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_stats_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/get_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/upload_avatar_use_case.dart';
import 'package:family_planner/features/profile/domain/use_cases/remove_avatar_use_case.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:family_planner/features/profile/presentation/cubit/profile_state.dart';
import 'package:family_planner/features/profile/presentation/widgets/avatar_widget.dart';

/// Страница настроек профиля (моя анкета).
/// Позволяет изменить отображаемое имя, био, загрузить/удалить аватар.
final class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({
    required this.profileId,
    super.key,
  });

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ProfileRepository>();

    return BlocProvider(
      create: (_) => ProfileCubit(
        getProfileUseCase: GetProfileUseCase(repository: repository),
        updateProfileUseCase: UpdateProfileUseCase(repository: repository),
        uploadAvatarUseCase: UploadAvatarUseCase(repository: repository),
        removeAvatarUseCase: RemoveAvatarUseCase(repository: repository),
        getProfileStatsUseCase: GetProfileStatsUseCase(repository: repository),
      )..load(profileId),
      child: _ProfileSettingsView(profileId: profileId),
    );
  }
}

final class _ProfileSettingsView extends StatefulWidget {
  const _ProfileSettingsView({required this.profileId});

  final String profileId;

  @override
  State<_ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

final class _ProfileSettingsViewState extends State<_ProfileSettingsView> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  bool _hasChanges = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final state = context.read<ProfileCubit>().state;
    if (state case ProfileLoaded(:final profile) || ProfileUpdateSuccess(:final profile)) {
      final nameChanged = _nameController.text.trim() != profile.displayName;
      final bioChanged = _bioController.text.trim() != profile.bio;
      if (nameChanged != _hasChanges || bioChanged != _hasChanges) {
        setState(() {
          _hasChanges = nameChanged || bioChanged;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Изменить фото',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Сделать снимок'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      final contentType = picked.name.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      if (!mounted) return;
      await context
          .read<ProfileCubit>()
          .uploadAvatar(profileId: widget.profileId, bytes: bytes, contentType: contentType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить фото.')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Фото профиля будет удалено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ProfileCubit>().removeAvatar(widget.profileId);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await context.read<ProfileCubit>().updateProfile(
      profileId: widget.profileId,
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _hasChanges = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранён.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки профиля'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Сохранить'),
            ),
        ],
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          switch (state) {
            case ProfileInitial():
            case ProfileLoading():
              return const Center(child: CircularProgressIndicator());

            case ProfileFailure(:final message):
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<ProfileCubit>().load(widget.profileId),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );

            case AvatarUploading(:final profile):
            case ProfileUpdateSuccess(:final profile):
            case ProfileLoaded(:final profile):
              if (_nameController.text.isEmpty &&
                  state is ProfileLoaded) {
                _nameController.text = profile.displayName;
                _bioController.text = profile.bio;
              }

              final isUploading = state is AvatarUploading;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ── Avatar section ──────────────────────
                      const SizedBox(height: 16),
                      Stack(
                        children: [
                          AvatarWidget(
                            profile: profile,
                            radius: 56,
                          ),
                          if (isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(56),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: isUploading ? null : _pickAvatar,
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Загрузить фото'),
                          ),
                          if (profile.avatarUrl != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: isUploading ? null : _removeAvatar,
                              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                              label: Text(
                                'Удалить',
                                style: TextStyle(color: cs.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Display name ────────────────────────
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Отображаемое имя',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Имя не может быть пустым.';
                          }
                          return null;
                        },
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 16),

                      // ── Bio ─────────────────────────────────
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'О себе',
                          prefixIcon: Icon(Icons.info_outline),
                          alignLabelWithHint: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        maxLength: 300,
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 24),

                      // ── Save button (always visible) ─────────
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _hasChanges && !isUploading
                              ? _saveProfile
                              : null,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Сохранить изменения'),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
