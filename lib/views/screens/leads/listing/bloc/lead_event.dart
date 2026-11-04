part of 'lead_bloc.dart';

abstract class LeadEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLeads extends LeadEvent {}

class StreamLead extends LeadEvent {}

class UpdateLeadStatus extends LeadEvent {
  final LeadModel lead;
  final String newStatusUid;
  UpdateLeadStatus({required this.lead, required this.newStatusUid});
}

class DeleteLead extends LeadEvent {
  final String uid;
  DeleteLead(this.uid);

  @override
  List<Object> get props => [uid];
}

class StreamLeadComments extends LeadEvent {
  final String leadUid;
  StreamLeadComments(this.leadUid);
}

class AddLeadComment extends LeadEvent {
  final String leadUid;
  final String commentText;
  AddLeadComment({required this.leadUid, required this.commentText});
}

class StreamLeadHistory extends LeadEvent {
  final String leadUid;
  StreamLeadHistory(this.leadUid);
}

class StreamLeadActivities extends LeadEvent {
  final String leadUid;
  StreamLeadActivities(this.leadUid);
}

class AddLeadActivity extends LeadEvent {
  final String leadUid;
  final LeadActivityModel activity;

  AddLeadActivity({required this.leadUid, required this.activity});
}

class EditLeadActivity extends LeadEvent {
  final String leadUid;
  final LeadActivityModel activity;

  EditLeadActivity({required this.leadUid, required this.activity});
}

class DeleteLeadActivity extends LeadEvent {
  final String leadUid;
  final String activityUid;

  DeleteLeadActivity({required this.leadUid, required this.activityUid});
}
