part of 'lead_bloc.dart';

abstract class LeadState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LeadInitial extends LeadState {}

// Loading state
class LeadLoading extends LeadState {}

// Loaded state with user list
class LeadLoaded extends LeadState {
  final List<LeadModel> leads;
  final List<LeadStatusModel> allStatuses;

  LeadLoaded(this.leads, this.allStatuses);

  @override
  List<Object> get props => [leads, allStatuses];
}

class LeadError extends LeadState {
  final String message;
  LeadError(this.message);

  @override
  List<Object> get props => [message];
}

class LeadDetailLoaded extends LeadState {
  final List<LeadCommentModel> comments;
  final List<LeadHistoryModel> history;
  final List<LeadActivityModel> activities;

  LeadDetailLoaded({
    required this.comments,
    required this.history,
    required this.activities,
  });

  @override
  List<Object> get props => [comments, history, activities];
}

class LeadDetailError extends LeadState {
  final String message;
  LeadDetailError(this.message);

  @override
  List<Object> get props => [message];
}
