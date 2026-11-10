import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'department_event.dart';
part 'department_state.dart';

class DepartmentBloc extends Bloc<DepartmentEvent, DepartmentState> {
  List<DepartmentModel> allDepartments = [];

  DepartmentBloc() : super(DepartmentLoading()) {
    on<StreamDepartment>(_stream);
  }

  /// PHP API has no realtime channel: data is re-fetched after every write
  /// (ApiLive.changed) and polled every 30s for changes by other users.
  Future<void> _stream(StreamDepartment event, Emitter<DepartmentState> emit) async {
    emit(DepartmentLoading());
    await emit.forEach<List<DepartmentModel>>(
      ApiLive.watch({'department'}, () async {
        allDepartments = await DepartmentService.getAllDepartments();
        return allDepartments;
      }),
      onData: (items) => DepartmentLoaded(items),
      onError: (error, stackTrace) =>
          DepartmentError("Failed to load department, $error"),
    );
  }
}
