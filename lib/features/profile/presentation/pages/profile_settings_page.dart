import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
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

  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarContentType;
  bool _pendingAvatarRemoval = false;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _checkHasChanges(UserProfile currentProfile) {
    final nameChanged = _nameController.text.trim() != currentProfile.displayName;
    final bioChanged = _bioController.text.trim() != currentProfile.bio;
    final avatarChanged = _pendingAvatarBytes != null || _pendingAvatarRemoval;

    final newHasChanges = nameChanged || bioChanged || avatarChanged;
    if (newHasChanges != _hasChanges) {
      setState(() {
        _hasChanges = newHasChanges;
      });
    }
  }

  Future<void> _pickAvatar(UserProfile currentProfile) async {
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

      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarContentType = contentType;
        _pendingAvatarRemoval = false;
      });

      _checkHasChanges(currentProfile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать фото.')),
      );
    }
  }

  void _removeAvatar(UserProfile currentProfile) {
    setState(() {
      _pendingAvatarBytes = null;
      _pendingAvatarContentType = null;
      _pendingAvatarRemoval = true;
    });

    _checkHasChanges(currentProfile);
  }

  Future<void> _saveProfile(UserProfile currentProfile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final cubit = context.read<ProfileCubit>();

    try {
      if (_pendingAvatarRemoval) {
        await cubit.removeAvatar(widget.profileId);
      } else if (_pendingAvatarBytes != null && _pendingAvatarContentType != null) {
        await cubit.uploadAvatar(
          profileId: widget.profileId,
          bytes: _pendingAvatarBytes!,
          contentType: _pendingAvatarContentType!,
        );
      }

      await cubit.updateProfile(
        profileId: widget.profileId,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _pendingAvatarBytes = null;
        _pendingAvatarContentType = null;
        _pendingAvatarRemoval = false;
        _isSaving = false;
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль сохранён.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileFailure) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final profile = switch (state) {
          ProfileLoaded(:final profile) => profile,
          ProfileUpdateSuccess(:final profile) => profile,
          AvatarUploading(:final profile) => profile,
          _ => null,
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Настройки профиля'),
            actions: [
              if (_hasChanges && profile != null)
                TextButton(
                  onPressed: _isSaving ? null : () => _saveProfile(profile),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
            ],
          ),
          body: () {
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

              case AvatarUploading():
              case ProfileUpdateSuccess():
              case ProfileLoaded():
                if (profile == null) return const SizedBox.shrink();

                if (_nameController.text.isEmpty && !_hasChanges) {
                  _nameController.text = profile.displayName;
                  _bioController.text = profile.bio;
                }

                // Determine display avatar state for preview
                final displayProfile = _pendingAvatarRemoval
                    ? profile.copyWith(clearAvatar: true)
                    : profile;

                final hasAvatarToDisplay = _pendingAvatarBytes != null ||
                    (displayProfile.avatarUrl != null &&
                        displayProfile.avatarUrl!.isNotEmpty);

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
                              profile: displayProfile,
                              imageBytes: _pendingAvatarBytes,
                              radius: 56,
                            ),
                            if (_isSaving)
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
                              onPressed:
                                  _isSaving ? null : () => _pickAvatar(profile),
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 18),
                              label: const Text('Загрузить фото'),
                            ),
                            if (hasAvatarToDisplay) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () => _removeAvatar(profile),
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: cs.error),
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
                          enabled: !_isSaving,
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
                          onChanged: (_) => _checkHasChanges(profile),
                        ),
                        const SizedBox(height: 16),

                        // ── Bio ─────────────────────────────────
                        TextFormField(
                          controller: _bioController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'О себе',
                            prefixIcon: Icon(Icons.info_outline),
                            alignLabelWithHint: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          maxLength: 300,
                          onChanged: (_) => _checkHasChanges(profile),
                        ),
                        const SizedBox(height: 24),

                        // ── Save button ─────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _hasChanges && !_isSaving
                                ? () => _saveProfile(profile)
                                : null,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Сохранить изменения'),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
            }
          }(),
        );
      },
    );
  }
}