part of 'projects_bloc.dart';

abstract class ProjectsState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class ProjectsInitial extends ProjectsState {}

// Loading state
class ProjectsLoading extends ProjectsState {}

// Loaded state with user list
class ProjectsLoaded extends ProjectsState {
  final List<ProjectModel> projects;
  ProjectsLoaded(this.projects);

  @override
  List<Object> get props => [projects];
}

// Error state
class ProjectsError extends ProjectsState {
  final String message;
  ProjectsError(this.message);

  @override
  List<Object> get props => [message];
}
