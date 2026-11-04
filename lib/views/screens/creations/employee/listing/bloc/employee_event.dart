part of 'employee_bloc.dart';

abstract class EmployeeEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchEmployees extends EmployeeEvent {}

class StreamEmployee extends EmployeeEvent {}

class DeleteEmployee extends EmployeeEvent {
  final String uid;

  DeleteEmployee({required this.uid});

  @override
  List<Object> get props => [uid];
}

abstract class UsersEvent {}

class StreamUsers extends UsersEvent {}

class DeleteUser extends UsersEvent {
  final UserRowModel user;
  DeleteUser(this.user);
}

