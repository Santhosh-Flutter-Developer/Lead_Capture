part of 'lead_source_bloc.dart';

abstract class LeadSourceState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LeadSourceInitial extends LeadSourceState {}

// Loading state
class LeadSourceLoading extends LeadSourceState {}

// Loaded state with user list
class LeadSourceLoaded extends LeadSourceState {
  final List<LeadSourceModel> leadSource;
  LeadSourceLoaded(this.leadSource);

  @override
  List<Object> get props => [leadSource];
}

// Error state
class LeadSourceError extends LeadSourceState {
  final String message;
  LeadSourceError(this.message);

  @override
  List<Object> get props => [message];
}
