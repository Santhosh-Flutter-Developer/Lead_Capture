import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'payment_mode_event.dart';
part 'payment_mode_state.dart';

class PaymentModeBloc extends Bloc<PaymentModeEvent, PaymentModeState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<PaymentModeModel> allPaymentModes = [];

  PaymentModeBloc() : super(PaymentModeLoading()) {
    on<StreamPaymentMode>(_streamPaymentModes);
    on<DeletePaymentMode>(_deletePaymentMode);
  }

  Future<void> _streamPaymentModes(
    StreamPaymentMode event,
    Emitter<PaymentModeState> emit,
  ) async {
    emit(PaymentModeLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .snapshots()
          .map((snapshot) {
            allPaymentModes = snapshot.docs
                .map((doc) => PaymentModeModel.fromMap(doc.id, doc.data()))
                .toList();

            return allPaymentModes;
          }),
      onData: (paymentMode) => PaymentModeLoaded(paymentMode),
      onError: (error, stackTrace) {
        return PaymentModeError("Failed to load paymentMode, $error");
      },
    );
  }

  Future<void> _deletePaymentMode(
    DeletePaymentMode event,
    Emitter<PaymentModeState> emit,
  ) async {
    try {
      await PaymentModeService.deletePaymentMode(uid: event.uid);

      var updatedList = await PaymentModeService.getAllPaymentMode();
      emit(PaymentModeLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(PaymentModeError("Failed to delete deal status: $e"));
    }
  }
}