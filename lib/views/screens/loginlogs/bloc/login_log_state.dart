part of 'login_log_bloc.dart';

abstract class LoginLogsState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LoginLogsInitial extends LoginLogsState {}

// Loading state
class LoginLogsLoading extends LoginLogsState {}

// Loaded state with user list
class LoginLogsLoaded extends LoginLogsState {
  final List<LoginLogsModel> loginLog;
  LoginLogsLoaded(this.loginLog);

  @override
  List<Object> get props => [loginLog];
}

// Error state
class LoginLogsError extends LoginLogsState {
  final String message;
  LoginLogsError(this.message);

  @override
  List<Object> get props => [message];
}
