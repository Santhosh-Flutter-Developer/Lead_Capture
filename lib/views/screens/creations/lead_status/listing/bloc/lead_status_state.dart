part of 'lead_status_bloc.dart';

abstract class LeadStatusState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LeadStatusInitial extends LeadStatusState {}

// Loading state
class LeadStatusLoading extends LeadStatusState {}

// Loaded state with user list
class LeadStatusLoaded extends LeadStatusState {
  final List<LeadStatusModel> leadStatus;
  LeadStatusLoaded(this.leadStatus);

  @override
  List<Object> get props => [leadStatus];
}

// Error state
class LeadStatusError extends LeadStatusState {
  final String message;
  LeadStatusError(this.message);

  @override
  List<Object> get props => [message];
}
