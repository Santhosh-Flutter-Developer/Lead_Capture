part of 'lead_source_bloc.dart';

abstract class LeadSourceEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLeadSources extends LeadSourceEvent {}

class StreamLeadSource extends LeadSourceEvent {}

class DeleteLeadSource extends LeadSourceEvent {
  final String uid;
  DeleteLeadSource(this.uid);
}
