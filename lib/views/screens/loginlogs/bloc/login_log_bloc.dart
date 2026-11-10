import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/api/api.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'login_log_event.dart';
part 'login_log_state.dart';

class LoginLogsBloc extends Bloc<LoginLogsEvent, LoginLogsState> {
  List<LoginLogsModel> allLoginLogs = [];

  LoginLogsBloc() : super(LoginLogsLoading()) {
    on<StreamLoginLogs>(_streamLoginLogs);
  }

  /// logs.php `login` (latest 250), refreshed every 30 s.
  Future<void> _streamLoginLogs(
    StreamLoginLogs event,
    Emitter<LoginLogsState> emit,
  ) async {
    emit(LoginLogsLoading());

    await emit.forEach<List<LoginLogsModel>>(
      ApiLive.watch<List<LoginLogsModel>>({'login_logs'}, () async {
        final res = (await ApiClient.instance.post(
          ApiEndpoints.logs,
          action: 'login',
        ))
            .ensureSuccess();
        allLoginLogs = Js.mapList(res.data).map((m) {
          final at = Js.dt(m['date_time']) ?? DateTime.now();
          final friendly = Js.s(m['friendly_device']);
          return LoginLogsModel(
            uid: Js.s(m['id']),
            loginTime: at,
            user: UserDataModel(
              uid: Js.s(m['user_uid']),
              name: Js.s(m['user_name']),
              profilePic: ApiConfig.resolveFileUrl(Js.opt(m['user_photo'])),
              desc: Js.opt(m['user_desc']),
              userType: Js.s(m['user_type']).toLowerCase() == 'admin'
                  ? UserType.admin
                  : UserType.employee,
            ),
            loginAlert: LoginAlertModel(
              ipAddress: Js.s(m['ip_address']),
              location: Js.s(m['location']),
              dateTime: at,
              device: friendly.isNotEmpty ? friendly : Js.s(m['device']),
            ),
          );
        }).toList();
        return allLoginLogs;
      }),
      onData: (loginLogs) => LoginLogsLoaded(loginLogs),
      onError: (error, stackTrace) =>
          LoginLogsError("Failed to load loginLogs, $error"),
    );
  }
}
