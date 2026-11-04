part of 'activity_log_bloc.dart';

abstract class ActivityLogsState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class ActivityLogsInitial extends ActivityLogsState {}

// Loading state
class ActivityLogsLoading extends ActivityLogsState {}

// Loaded state with user list
class ActivityLogsLoaded extends ActivityLogsState {
  final List<ActivityLogModel> activityLogs;
  ActivityLogsLoaded(this.activityLogs);

  @override
  List<Object> get props => [activityLogs];
}

// Error state
class ActivityLogsError extends ActivityLogsState {
  final String message;
  ActivityLogsError(this.message);

  @override
  List<Object> get props => [message];
}
