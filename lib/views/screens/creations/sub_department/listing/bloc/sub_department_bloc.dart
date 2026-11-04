import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'sub_department_event.dart';
part 'sub_department_state.dart';

class SubDepartmentBloc extends Bloc<SubDepartmentEvent, SubDepartmentState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<SubDepartmentModel> allSubDepartments = [];

  SubDepartmentBloc() : super(SubDepartmentLoading()) {
    on<StreamSubDepartment>(_streamSubDepartments);
  }

  Future<void> _streamSubDepartments(
      StreamSubDepartment event, Emitter<SubDepartmentState> emit) async {
    emit(SubDepartmentLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.subDepartments.name)
          .snapshots()
          .map((snapshot) {
        allSubDepartments = snapshot.docs
            .map((doc) => SubDepartmentModel.fromMap(doc.id, doc.data()))
            .toList();

        return allSubDepartments;
      }),
      onData: (subSubDepartments) => SubDepartmentLoaded(subSubDepartments),
      onError: (error, stackTrace) {
        return SubDepartmentError("Failed to load sub department, $error");
      },
    );
  }
}
