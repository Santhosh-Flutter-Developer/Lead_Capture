import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'login_log_event.dart';
part 'login_log_state.dart';

class LoginLogsBloc extends Bloc<LoginLogsEvent, LoginLogsState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<LoginLogsModel> allLoginLogs = [];

  LoginLogsBloc() : super(LoginLogsLoading()) {
    on<StreamLoginLogs>(_streamLoginLogs);
  }

  Future<void> _streamLoginLogs(
    StreamLoginLogs event,
    Emitter<LoginLogsState> emit,
  ) async {
    emit(LoginLogsLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.loginLogs.name)
          .orderBy('loginTime', descending: true)
          .snapshots()
          .map((snapshot) {
            allLoginLogs = snapshot.docs
                .map((doc) => LoginLogsModel.fromMap(doc.data()))
                .toList();

            return allLoginLogs;
          }),
      onData: (loginLogs) => LoginLogsLoaded(loginLogs),
      onError: (error, stackTrace) {
        return LoginLogsError("Failed to load loginLogs, $error");
      },
    );
  }
}
