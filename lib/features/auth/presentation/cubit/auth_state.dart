part of 'auth_cubit.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Mashina raqami kiritildi -> parol sahifasiga o'tish.
class CarNumberEntered extends AuthState {
  final String carNumber;

  const CarNumberEntered(this.carNumber);

  @override
  List<Object> get props => [carNumber];
}

class AuthSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
