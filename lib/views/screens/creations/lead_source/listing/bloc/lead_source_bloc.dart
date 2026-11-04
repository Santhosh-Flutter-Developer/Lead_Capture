import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_source_event.dart';
part 'lead_source_state.dart';

class LeadSourceBloc extends Bloc<LeadSourceEvent, LeadSourceState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<LeadSourceModel> allLeadSources = [];

  LeadSourceBloc() : super(LeadSourceLoading()) {
    on<StreamLeadSource>(_streamLeadSources);
    on<DeleteLeadSource>(_deleteLeadSource);
  }

  Future<void> _streamLeadSources(
    StreamLeadSource event,
    Emitter<LeadSourceState> emit,
  ) async {
    emit(LeadSourceLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leadSource.name)
          .snapshots()
          .map((snapshot) {
            allLeadSources = snapshot.docs
                .map((doc) => LeadSourceModel.fromMap(doc.id, doc.data()))
                .toList();

            return allLeadSources;
          }),
      onData: (leadSource) => LeadSourceLoaded(leadSource),
      onError: (error, stackTrace) {
        return LeadSourceError("Failed to load leadSource, $error");
      },
    );
  }

  Future<void> _deleteLeadSource(
    DeleteLeadSource event,
    Emitter<LeadSourceState> emit,
  ) async {
    try {
      await LeadSourceService.deleteLeadSource(uid: event.uid);

      var updatedList = await LeadSourceService.getAllLeadSource();
      emit(LeadSourceLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadSourceError("Failed to delete deal status: $e"));
    }
  }
}
