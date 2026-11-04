part of 'sub_department_bloc.dart';

abstract class SubDepartmentEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchSubDepartments extends SubDepartmentEvent {}

class StreamSubDepartment extends SubDepartmentEvent {}
