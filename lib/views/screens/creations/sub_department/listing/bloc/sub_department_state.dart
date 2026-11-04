part of 'sub_department_bloc.dart';

abstract class SubDepartmentState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class SubDepartmentInitial extends SubDepartmentState {}

// Loading state
class SubDepartmentLoading extends SubDepartmentState {}

// Loaded state with user list
class SubDepartmentLoaded extends SubDepartmentState {
  final List<SubDepartmentModel> subDepartments;
  SubDepartmentLoaded(this.subDepartments);

  @override
  List<Object> get props => [subDepartments];
}

// Error state
class SubDepartmentError extends SubDepartmentState {
  final String message;
  SubDepartmentError(this.message);

  @override
  List<Object> get props => [message];
}
