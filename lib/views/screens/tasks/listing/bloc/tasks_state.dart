part of 'tasks_bloc.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<TaskModel> tasks;

  const TaskLoaded(this.tasks);

  @override
  List<Object?> get props => [tasks];
}

class TaskDeleting extends TaskState {}

class TaskDeleted extends TaskState {}

class TaskError extends TaskState {
  final String message;

  const TaskError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class TaskHistoryState extends Equatable {
  const TaskHistoryState();

  @override
  List<Object?> get props => [];
}

class TaskHistoryLoading extends TaskHistoryState {}

class TaskHistoryLoaded extends TaskHistoryState {
  final List<TaskHistoryModel> taskHistory;

  const TaskHistoryLoaded(this.taskHistory);

  @override
  List<Object?> get props => [taskHistory];
}

class TaskHistoryError extends TaskHistoryState {
  final String message;

  const TaskHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class TaskCommentsState extends Equatable {
  const TaskCommentsState();

  @override
  List<Object?> get props => [];
}

class TaskCommentsLoading extends TaskCommentsState {}

class TaskCommentsLoaded extends TaskCommentsState {
  final List<TaskCommentModel> taskComments;

  const TaskCommentsLoaded(this.taskComments);

  @override
  List<Object?> get props => [taskComments];
}

class TaskCommentsError extends TaskCommentsState {
  final String message;

  const TaskCommentsError(this.message);

  @override
  List<Object?> get props => [message];
}
