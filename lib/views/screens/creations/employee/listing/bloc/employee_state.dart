part of 'employee_bloc.dart';

abstract class EmployeeState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class EmployeeInitial extends EmployeeState {}

// Loading state
class EmployeeLoading extends EmployeeState {}

// Loaded state with user list
class EmployeeLoaded extends EmployeeState {
  final List<EmployeeModel> employees;
  EmployeeLoaded(this.employees);

  @override
  List<Object> get props => [employees];
}

// Error state
class EmployeeError extends EmployeeState {
  final String message;
  EmployeeError(this.message);

  @override
  List<Object> get props => [message];
}

abstract class UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserRowModel> users;
  UsersLoaded(this.users);
}

class UsersError extends UsersState {
  final String message;
  UsersError(this.message);
}

