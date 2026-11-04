part of 'lead_priority_bloc.dart';

abstract class LeadPriorityEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLeadPrioritys extends LeadPriorityEvent {}

class StreamLeadPriority extends LeadPriorityEvent {}

class DeleteLeadPriority extends LeadPriorityEvent {
  final String uid;

  DeleteLeadPriority({required this.uid});
}
