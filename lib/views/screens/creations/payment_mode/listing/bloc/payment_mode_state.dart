part of 'payment_mode_bloc.dart';

abstract class PaymentModeState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class PaymentModeInitial extends PaymentModeState {}

// Loading state
class PaymentModeLoading extends PaymentModeState {}

// Loaded state with user list
class PaymentModeLoaded extends PaymentModeState {
  final List<PaymentModeModel> paymentMode;
  PaymentModeLoaded(this.paymentMode);

  @override
  List<Object> get props => [paymentMode];
}

// Error state
class PaymentModeError extends PaymentModeState {
  final String message;
  PaymentModeError(this.message);

  @override
  List<Object> get props => [message];
}