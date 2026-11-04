part of 'department_bloc.dart';

abstract class DepartmentEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchDepartments extends DepartmentEvent {}

class StreamDepartment extends DepartmentEvent {}
