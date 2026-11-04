part of 'lead_priority_bloc.dart';

abstract class LeadPriorityState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LeadPriorityInitial extends LeadPriorityState {}

// Loading state
class LeadPriorityLoading extends LeadPriorityState {}

// Loaded state with user list
class LeadPriorityLoaded extends LeadPriorityState {
  final List<LeadPriorityModel> leadPriority;
  LeadPriorityLoaded(this.leadPriority);

  @override
  List<Object> get props => [leadPriority];
}

// Error state
class LeadPriorityError extends LeadPriorityState {
  final String message;
  LeadPriorityError(this.message);

  @override
  List<Object> get props => [message];
}
