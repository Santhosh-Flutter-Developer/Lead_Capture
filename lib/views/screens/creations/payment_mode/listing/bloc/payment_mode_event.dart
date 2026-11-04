part of 'payment_mode_bloc.dart';

abstract class PaymentModeEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchPaymentModes extends PaymentModeEvent {}

class StreamPaymentMode extends PaymentModeEvent {}

class DeletePaymentMode extends PaymentModeEvent {
  final String uid;
  DeletePaymentMode(this.uid);
}