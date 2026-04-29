part of 'profile_cubit.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileImageSelected extends ProfileState {
  final File image;

  const ProfileImageSelected(this.image);

  @override
  List<Object> get props => [image];
}

class ProfileCompleted extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final DriverProfileModel profile;
  final DriverDataModel? data;

  const ProfileLoaded({required this.profile, this.data});

  @override
  List<Object?> get props => [profile, data];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}
