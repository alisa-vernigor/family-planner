import 'dart:typed_data';

import '../../domain/repositories/profile_repository.dart';

final class UploadAvatarUseCase {
  UploadAvatarUseCase({required this.repository});

  final ProfileRepository repository;

  Future<String> call({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return repository.uploadAvatar(
      profileId: profileId,
      bytes: bytes,
      contentType: contentType,
    );
  }
}
