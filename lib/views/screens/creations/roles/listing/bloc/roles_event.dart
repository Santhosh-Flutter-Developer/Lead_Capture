part of 'roles_bloc.dart';

abstract class RolesEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchRoless extends RolesEvent {}

class StreamRoles extends RolesEvent {}
