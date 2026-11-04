part of 'deal_status_bloc.dart';

abstract class DealStatusEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchDealStatuss extends DealStatusEvent {}

class StreamDealStatus extends DealStatusEvent {}

class DeleteDealStatus extends DealStatusEvent {
  final String uid;

  DeleteDealStatus({required this.uid});

  @override
  List<Object> get props => [uid];
}
