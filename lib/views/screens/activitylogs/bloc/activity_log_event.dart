part of 'activity_log_bloc.dart';

abstract class ActivityLogsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchActivityLogss extends ActivityLogsEvent {}

class StreamActivityLogs extends ActivityLogsEvent {}
