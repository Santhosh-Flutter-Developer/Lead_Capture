part of 'projects_bloc.dart';

abstract class ProjectsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchProjectss extends ProjectsEvent {}

class StreamProjects extends ProjectsEvent {}

class DeleteProjects extends ProjectsEvent {
  final String uid;

  DeleteProjects({required this.uid});

  @override
  List<Object> get props => [uid];
}