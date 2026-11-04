import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/constants/constants.dart';
part 'tasks_event.dart';
part 'tasks_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<TaskModel> allTasks = [];

  TaskBloc() : super(TaskLoading()) {
    on<StreamTasks>(_streamTasks);
    on<DeleteTask>(_deleteTask);
  }

  Future<void> _streamTasks(StreamTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    try {
      final uid = await Spdb.getUid();
      final cid = await Spdb.getCid();

      final query = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.tasks.name)
          .where(
            Filter.or(
              Filter('assignees', arrayContains: uid),
              Filter('createdBy', arrayContains: uid),
              Filter('observers', arrayContains: uid),
              Filter('participants', arrayContains: uid),
            ),
          )
          .orderBy('createdAt', descending: true);

      await emit.forEach<List<TaskModel>>(
        query.snapshots().map((snapshot) {
          allTasks = snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
              .toList();
          return allTasks;
        }),
        onData: (tasks) => TaskLoaded(tasks),
        onError: (e, st) {
          return TaskError("Failed to load tasks: $e");
        },
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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<TaskHistoryModel> allTasks = [];

  TaskHistoryBloc() : super(TaskHistoryLoading()) {
    on<StreamTaskHistory>(_streamTaskHistory);
  }

  Future<void> _streamTaskHistory(
    StreamTaskHistory event,
    Emitter<TaskHistoryState> emit,
  ) async {
    emit(TaskHistoryLoading());
    try {
      final cid = await Spdb.getCid();

      await emit.forEach<List<TaskHistoryModel>>(
        firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.tasks.name)
            .doc(event.uid)
            .collection(Collections.taskHistory.name)
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              allTasks = snapshot.docs
                  .map((doc) => TaskHistoryModel.fromMap(doc.data()))
                  .toList();
              return allTasks;
            }),
        onData: (tasks) => TaskHistoryLoaded(tasks),
        onError: (e, st) {
          debugPrint(st.toString());
          return TaskHistoryError("Failed to load tasks: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      emit(TaskHistoryError("Error streaming tasks: $e"));
    }
  }
}

class TaskCommentsBloc extends Bloc<TaskCommentsEvent, TaskCommentsState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<TaskCommentModel> allTasks = [];

  TaskCommentsBloc() : super(TaskCommentsLoading()) {
    on<StreamTaskComments>(_streamTaskComment);
  }

  Future<void> _streamTaskComment(
    StreamTaskComments event,
    Emitter<TaskCommentsState> emit,
  ) async {
    emit(TaskCommentsLoading());
    try {
      final cid = await Spdb.getCid();

      await emit.forEach<List<TaskCommentModel>>(
        firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.tasks.name)
            .doc(event.uid)
            .collection(Collections.taskComments.name)
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              allTasks = snapshot.docs
                  .map((doc) => TaskCommentModel.fromMap(doc.data()))
                  .toList();
              return allTasks;
            }),
        onData: (tasks) => TaskCommentsLoaded(tasks),
        onError: (e, st) {
          debugPrint(st.toString());
          return TaskCommentsError("Failed to load tasks: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      emit(TaskCommentsError("Error streaming tasks: $e"));
    }
  }
}
