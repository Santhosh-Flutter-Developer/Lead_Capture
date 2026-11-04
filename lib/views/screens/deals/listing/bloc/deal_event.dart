part of 'deal_bloc.dart';

abstract class DealEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchDeals extends DealEvent {}

class StreamDeals extends DealEvent {}

class UpdateDealStatus extends DealEvent {
  final DealModel deal;
  final String newStatusUid;

  UpdateDealStatus({required this.deal, required this.newStatusUid});

  @override
  List<Object> get props => [deal, newStatusUid];
}

class StreamDealComments extends DealEvent {
  final String dealUid;
  StreamDealComments(this.dealUid);
}

class AddDealComment extends DealEvent {
  final String dealUid;
  final String commentText;

  AddDealComment({required this.dealUid, required this.commentText});
}

class StreamDealHistory extends DealEvent {
  final String dealUid;
  StreamDealHistory(this.dealUid);
}

class AddDealHistory extends DealEvent {
  final String dealUid;
  final String action;

  AddDealHistory({required this.dealUid, required this.action});
}

class DeleteDeal extends DealEvent {
  final String dealUid;

  DeleteDeal(this.dealUid);

  @override
  List<Object> get props => [dealUid];
}

class StreamDealActivities extends DealEvent {
  final String dealUid;
  StreamDealActivities(this.dealUid);
}

class AddDealActivity extends DealEvent {
  final String dealUid;
  final DealActivityModel activity;

  AddDealActivity({required this.dealUid, required this.activity});
}

class EditDealActivity extends DealEvent {
  final String dealUid;
  final DealActivityModel activity;

  EditDealActivity({required this.dealUid, required this.activity});
}

class DeleteDealActivity extends DealEvent {
  final String dealUid;
  final String activityUid;

  DeleteDealActivity({required this.dealUid, required this.activityUid});
}
