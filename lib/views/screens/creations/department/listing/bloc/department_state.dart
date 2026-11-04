part of 'department_bloc.dart';

abstract class DepartmentState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class DepartmentInitial extends DepartmentState {}

// Loading state
class DepartmentLoading extends DepartmentState {}

// Loaded state with user list
class DepartmentLoaded extends DepartmentState {
  final List<DepartmentModel> department;
  DepartmentLoaded(this.department);

  @override
  List<Object> get props => [department];
}

// Error state
class DepartmentError extends DepartmentState {
  final String message;
  DepartmentError(this.message);

  @override
  List<Object> get props => [message];
}
