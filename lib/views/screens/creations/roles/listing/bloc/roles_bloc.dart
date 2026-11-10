import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'roles_event.dart';
part 'roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  List<RoleModel> allRoles = [];

  RolesBloc() : super(RolesLoading()) {
    on<StreamRoles>(_streamRoless);
  }

  Future<void> _streamRoless(
    StreamRoles event,
    Emitter<RolesState> emit,
  ) async {
    emit(RolesLoading());
    await emit.forEach<RolesLoaded>(
      // 'employee' too: assigning a role changes the per-role employee count.
      ApiLive.watch({'role', 'employee'}, () async {
        final rows = (await RolesApiService.list()).ensureSuccess().dataList.map(Js.m).toList();
        allRoles = rows.map(ApiMappers.role).toList();
        final counts = <String, int>{
          for (final r in rows)
            if ((Js.i(r['employee_count']) ?? 0) > 0) Js.s(r['uid']): Js.i(r['employee_count'])!,
        };
        return RolesLoaded(allRoles, employeeCounts: counts);
      }),
      onData: (loaded) => loaded,
      onError: (error, stackTrace) => RolesError("Failed to load role, $error"),
    );
  }
}
