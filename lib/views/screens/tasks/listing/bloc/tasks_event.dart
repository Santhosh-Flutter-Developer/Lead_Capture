part of 'tasks_bloc.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class StreamTasks extends TaskEvent {}

class DeleteTask extends TaskEvent {
  final String uid;
  const DeleteTask(this.uid);
  @override
  List<Object?> get props => [uid];
}

abstract class TaskHistoryEvent extends Equatable {
  const TaskHistoryEvent();

  @override
  List<Object?> get props => [];
}

class StreamTaskHistory extends TaskHistoryEvent {
  final String uid;
  const StreamTaskHistory(this.uid);
  @override
  List<Object?> get props => [uid];
}

abstract class TaskCommentsEvent extends Equatable {
  const TaskCommentsEvent();

  @override
  List<Object?> get props => [];
}

class StreamTaskComments extends TaskCommentsEvent {
  final String uid;
  const StreamTaskComments(this.uid);
  @override
  List<Object?> get props => [uid];
}
