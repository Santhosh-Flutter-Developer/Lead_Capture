part of 'deal_status_bloc.dart';

abstract class DealStatusState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class DealStatusInitial extends DealStatusState {}

// Loading state
class DealStatusLoading extends DealStatusState {}

// Loaded state with user list
class DealStatusLoaded extends DealStatusState {
  final List<DealStatusModel> dealStatus;
  DealStatusLoaded(this.dealStatus);

  @override
  List<Object> get props => [dealStatus];
}

// Error state
class DealStatusError extends DealStatusState {
  final String message;
  DealStatusError(this.message);

  @override
  List<Object> get props => [message];
}
