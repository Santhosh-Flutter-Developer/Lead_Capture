import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'activity_log_event.dart';
part 'activity_log_state.dart';

class ActivityLogsBloc extends Bloc<ActivityLogsEvent, ActivityLogsState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<ActivityLogModel> allActivityLogs = [];

  ActivityLogsBloc() : super(ActivityLogsLoading()) {
    on<StreamActivityLogs>(_streamActivityLogs);
  }

  Future<void> _streamActivityLogs(
    StreamActivityLogs event,
    Emitter<ActivityLogsState> emit,
  ) async {
    emit(ActivityLogsLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.activityLogs.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            allActivityLogs = snapshot.docs
                .map((doc) => ActivityLogModel.fromMap(doc.data()))
                .toList();

            return allActivityLogs;
          }),
      onData: (activityLogs) => ActivityLogsLoaded(activityLogs),
      onError: (error, stackTrace) {
        return ActivityLogsError("Failed to load activityLogs, $error");
      },
    );
  }
}
