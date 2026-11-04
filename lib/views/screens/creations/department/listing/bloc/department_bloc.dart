import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'department_event.dart';
part 'department_state.dart';

class DepartmentBloc extends Bloc<DepartmentEvent, DepartmentState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<DepartmentModel> allDepartments = [];

  DepartmentBloc() : super(DepartmentLoading()) {
    on<StreamDepartment>(_streamDepartments);
  }

  Future<void> _streamDepartments(
      StreamDepartment event, Emitter<DepartmentState> emit) async {
    emit(DepartmentLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.departments.name)
          .snapshots()
          .map((snapshot) {
        allDepartments = snapshot.docs
            .map((doc) => DepartmentModel.fromMap(doc.id, doc.data()))
            .toList();

        return allDepartments;
      }),
      onData: (departments) => DepartmentLoaded(departments),
      onError: (error, stackTrace) {
        return DepartmentError("Failed to load department, $error");
      },
    );
  }
}
