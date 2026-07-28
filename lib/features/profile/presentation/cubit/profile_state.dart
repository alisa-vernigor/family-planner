import 'package:equatable/equatable.dart';

import '../../domain/entities/user_profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.profile});

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class ProfileUpdateSuccess extends ProfileState {
  const ProfileUpdateSuccess({required this.profile});

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class AvatarUploading extends ProfileState {
  const AvatarUploading({required this.profile});

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

final class ProfileFailure extends ProfileState {
  const ProfileFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
