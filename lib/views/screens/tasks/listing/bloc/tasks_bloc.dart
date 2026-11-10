import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';
part 'tasks_event.dart';
part 'tasks_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  List<TaskModel> allTasks = [];

  TaskBloc() : super(TaskLoading()) {
    on<StreamTasks>(_streamTasks);
    on<DeleteTask>(_deleteTask);
  }

  Future<void> _streamTasks(StreamTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    try {
      await emit.forEach<List<TaskModel>>(
        ApiLive.watch({'tasks'}, () async => allTasks = await TaskService.getMyTasks()),
        onData: (tasks) => TaskLoaded(tasks),
        onError: (e, st) => TaskError("Failed to load tasks: $e"),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TaskError("Error streaming tasks: $e"));
    }
  }

  Future<void> _deleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      emit(TaskDeleting());
      await TaskService.deleteTask(uid: event.uid);
      emit(TaskDeleted());
      add(StreamTasks());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TaskError("Failed to delete task: $e"));
    }
  }
}

class TaskHistoryBloc extends Bloc<TaskHistoryEvent, TaskHistoryState> {
  TaskHistoryBloc() : super(TaskHistoryLoading()) {
    on<StreamTaskHistory>(_streamTaskHistory);
  }

  Future<void> _streamTaskHistory(
    StreamTaskHistory event,
    Emitter<TaskHistoryState> emit,
  ) async {
    emit(TaskHistoryLoading());
    // tasks.php has no task-history table (see MISSING_API_REQUIREMENTS.md).
    emit(TaskHistoryLoaded(const []));
  }
}

class TaskCommentsBloc extends Bloc<TaskCommentsEvent, TaskCommentsState> {
  TaskCommentsBloc() : super(TaskCommentsLoading()) {
    on<StreamTaskComments>(_streamTaskComment);
  }

  Future<void> _streamTaskComment(
    StreamTaskComments event,
    Emitter<TaskCommentsState> emit,
  ) async {
    emit(TaskCommentsLoading());
    try {
      await emit.forEach<List<TaskCommentModel>>(
        TaskService.streamComments(cid: '', taskId: event.uid),
        onData: (c) => TaskCommentsLoaded(c),
        onError: (e, st) {
          debugPrint(st.toString());
          return TaskCommentsError("Failed to load comments: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TaskCommentsError("Error streaming comments: $e"));
    }
  }
}
