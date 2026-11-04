import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'deal_status_event.dart';
part 'deal_status_state.dart';

class DealStatusBloc extends Bloc<DealStatusEvent, DealStatusState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<DealStatusModel> allDealStatus = [];

  DealStatusBloc() : super(DealStatusLoading()) {
    on<StreamDealStatus>(_streamDealStatus);
    on<DeleteDealStatus>(_deleteDealStatus);
  }

  Future<void> _streamDealStatus(
    StreamDealStatus event,
    Emitter<DealStatusState> emit,
  ) async {
    emit(DealStatusLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.dealStatus.name)
          .orderBy('orderNumber', descending: true)
          .snapshots()
          .map((snapshot) {
            allDealStatus = snapshot.docs
                .map((doc) => DealStatusModel.fromMap(doc.id, doc.data()))
                .toList();

            return allDealStatus;
          }),
      onData: (dealStatus) => DealStatusLoaded(dealStatus),
      onError: (error, stackTrace) {
        return DealStatusError("Failed to load dealStatus, $error");
      },
    );
  }

  Future<void> _deleteDealStatus(
    DeleteDealStatus event,
    Emitter<DealStatusState> emit,
  ) async {
    try {
      await DealStatusService.deleteDealStatus(uid: event.uid);

      var updatedList = await DealStatusService.getAllDealStatus();
      emit(DealStatusLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(DealStatusError("Failed to delete deal status: $e"));
    }
  }
}
