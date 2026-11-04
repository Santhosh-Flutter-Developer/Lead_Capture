part of 'designation_bloc.dart';

abstract class DesignationEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchDesignations extends DesignationEvent {}

class StreamDesignation extends DesignationEvent {}
