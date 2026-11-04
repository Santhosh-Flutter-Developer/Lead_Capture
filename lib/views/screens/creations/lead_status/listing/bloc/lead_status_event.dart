part of 'lead_status_bloc.dart';

abstract class LeadStatusEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLeadStatuss extends LeadStatusEvent {}

class StreamLeadStatus extends LeadStatusEvent {}

class DeleteLeadStatus extends LeadStatusEvent {
  final String uid;

  DeleteLeadStatus({required this.uid});
}
