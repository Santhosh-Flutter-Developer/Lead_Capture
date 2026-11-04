part of 'login_log_bloc.dart';

abstract class LoginLogsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLoginLogss extends LoginLogsEvent {}

class StreamLoginLogs extends LoginLogsEvent {}
