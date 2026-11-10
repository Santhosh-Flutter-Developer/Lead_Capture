import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'sub_department_event.dart';
part 'sub_department_state.dart';

class SubDepartmentBloc extends Bloc<SubDepartmentEvent, SubDepartmentState> {
  List<SubDepartmentModel> allSubDepartments = [];

  SubDepartmentBloc() : super(SubDepartmentLoading()) {
    on<StreamSubDepartment>(_stream);
  }

  /// PHP API has no realtime channel: data is re-fetched after every write
  /// (ApiLive.changed) and polled every 30s for changes by other users.
  Future<void> _stream(StreamSubDepartment event, Emitter<SubDepartmentState> emit) async {
    emit(SubDepartmentLoading());
    await emit.forEach<List<SubDepartmentModel>>(
      ApiLive.watch({'sub_department'}, () async {
        allSubDepartments = await SubDepartmentService.getAllSubDepartments();
        return allSubDepartments;
      }),
      onData: (items) => SubDepartmentLoaded(items),
      onError: (error, stackTrace) =>
          SubDepartmentError("Failed to load sub department, $error"),
    );
  }
}
