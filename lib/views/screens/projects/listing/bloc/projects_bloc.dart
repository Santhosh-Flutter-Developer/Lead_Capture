import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'projects_event.dart';
part 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  List<ProjectModel> allProjectss = [];

  ProjectsBloc() : super(ProjectsLoading()) {
    on<StreamProjects>(_streamProjectss);
    on<DeleteProjects>(_deleteProjects);
  }

  Future<void> _streamProjectss(
    StreamProjects event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    await emit.forEach(
      ApiLive.watch({'projects'}, () async => allProjectss = await ProjectService.getAllProjects()),
      onData: (projects) => ProjectsLoaded(projects),
      onError: (error, stackTrace) {
        return ProjectsError("Failed to load projects, $error");
      },
    );
  }

  Future<void> _deleteProjects(
    DeleteProjects event,
    Emitter<ProjectsState> emit,
  ) async {
    try {
      await ProjectService.deleteProject(uid: event.uid);

      var updatedList = await ProjectService.getAllProjects();
      emit(ProjectsLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(ProjectsError("Failed to delete deal status: $e"));
    }
  }
}
