import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_status_event.dart';
part 'lead_status_state.dart';

class LeadStatusBloc extends Bloc<LeadStatusEvent, LeadStatusState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<LeadStatusModel> allLeadStatus = [];

  LeadStatusBloc() : super(LeadStatusLoading()) {
    on<StreamLeadStatus>(_streamLeadStatus);
    on<DeleteLeadStatus>(_deleteLeadStatus);
  }

  Future<void> _streamLeadStatus(
    StreamLeadStatus event,
    Emitter<LeadStatusState> emit,
  ) async {
    emit(LeadStatusLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leadStatus.name)
          .orderBy('orderNumber', descending: true)
          .snapshots()
          .map((snapshot) {
            allLeadStatus = snapshot.docs
                .map((doc) => LeadStatusModel.fromMap(doc.id, doc.data()))
                .toList();

            return allLeadStatus;
          }),
      onData: (leadStatus) => LeadStatusLoaded(leadStatus),
      onError: (error, stackTrace) {
        return LeadStatusError("Failed to load leadStatus, $error");
      },
    );
  }

  Future<void> _deleteLeadStatus(
    DeleteLeadStatus event,
    Emitter<LeadStatusState> emit,
  ) async {
    try {
      await LeadStatusService.deleteLeadStatus(uid: event.uid);

      var updatedList = await LeadStatusService.getAllLeadStatus();
      emit(LeadStatusLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadStatusError("Failed to delete leadStatus: $e"));
    }
  }
}
