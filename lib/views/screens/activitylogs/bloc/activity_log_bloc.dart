import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/api/api.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'activity_log_event.dart';
part 'activity_log_state.dart';

class ActivityLogsBloc extends Bloc<ActivityLogsEvent, ActivityLogsState> {
  List<ActivityLogModel> allActivityLogs = [];

  ActivityLogsBloc() : super(ActivityLogsLoading()) {
    on<StreamActivityLogs>(_streamActivityLogs);
  }

  /// logs.php `activity` (latest 300), refreshed every 30 s.
  Future<void> _streamActivityLogs(
    StreamActivityLogs event,
    Emitter<ActivityLogsState> emit,
  ) async {
    emit(ActivityLogsLoading());

    await emit.forEach<List<ActivityLogModel>>(
      ApiLive.watch<List<ActivityLogModel>>({'activity_logs'}, () async {
        final res = (await ApiClient.instance.post(
          ApiEndpoints.logs,
          action: 'activity',
        ))
            .ensureSuccess();
        allActivityLogs = Js.mapList(res.data).map((m) {
          final at = Js.dt(m['date_time']) ?? DateTime.now();
          return ActivityLogModel(
            uid: Js.s(m['id']),
            userData: UserDataModel(
              uid: Js.s(m['user_uid']),
              name: Js.s(m['user_name']),
              profilePic: ApiConfig.resolveFileUrl(Js.opt(m['user_photo'])),
              desc: Js.opt(m['user_desc']),
              userType: UserType.employee,
            ),
            activity: Js.s(m['action']),
            description: Js.opt(m['details']),
            collection: Js.s(m['page']),
            createdAt: at,
            updatedAt: at,
          );
        }).toList();
        return allActivityLogs;
      }),
      onData: (activityLogs) => ActivityLogsLoaded(activityLogs),
      onError: (error, stackTrace) =>
          ActivityLogsError("Failed to load activityLogs, $error"),
    );
  }
}
