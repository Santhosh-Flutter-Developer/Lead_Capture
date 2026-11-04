import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'designation_event.dart';
part 'designation_state.dart';

class DesignationBloc extends Bloc<DesignationEvent, DesignationState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<DesignationModel> allDesignations = [];

  DesignationBloc() : super(DesignationLoading()) {
    on<StreamDesignation>(_streamDesignations);
  }

  Future<void> _streamDesignations(
      StreamDesignation event, Emitter<DesignationState> emit) async {
    emit(DesignationLoading());
    var cid = await Spdb.getCid();
    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.designations.name)
          .snapshots()
          .map((snapshot) {
        allDesignations = snapshot.docs
            .map((doc) => DesignationModel.fromMap(doc.id, doc.data()))
            .toList();

        return allDesignations;
      }),
      onData: (designations) => DesignationLoaded(designations),
      onError: (error, stackTrace) {
        return DesignationError("Failed to load designation, $error");
      },
    );
  }
}
