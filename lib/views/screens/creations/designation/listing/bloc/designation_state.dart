part of 'designation_bloc.dart';

abstract class DesignationState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class DesignationInitial extends DesignationState {}

// Loading state
class DesignationLoading extends DesignationState {}

// Loaded state with user list
class DesignationLoaded extends DesignationState {
  final List<DesignationModel> designation;
  DesignationLoaded(this.designation);

  @override
  List<Object> get props => [designation];
}

// Error state
class DesignationError extends DesignationState {
  final String message;
  DesignationError(this.message);

  @override
  List<Object> get props => [message];
}
