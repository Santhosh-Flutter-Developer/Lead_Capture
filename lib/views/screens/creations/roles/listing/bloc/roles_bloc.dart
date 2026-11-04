import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'roles_event.dart';
part 'roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<RoleModel> allRoles = [];

  RolesBloc() : super(RolesLoading()) {
    on<StreamRoles>(_streamRoless);
  }

  Future<void> _streamRoless(
    StreamRoles event,
    Emitter<RolesState> emit,
  ) async {
    emit(RolesLoading());
    var cid = await Spdb.getCid();

    final rolesStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.roles.name)
        .snapshots();

    final employeesStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.employees.name)
        .snapshots();

    await emit.forEach<RolesLoaded>(
      Rx.combineLatest2(rolesStream, employeesStream, (rolesSnap, empSnap) {
        allRoles = rolesSnap.docs
            .map((doc) => RoleModel.fromMap(doc.id, doc.data()))
            .toList();

        final counts = <String, int>{};
        for (final doc in empSnap.docs) {
          final roleId = doc.data()['role']?.toString() ?? '';
          if (roleId.isEmpty) continue;
          counts[roleId] = (counts[roleId] ?? 0) + 1;
        }

        return RolesLoaded(allRoles, employeeCounts: counts);
      }),
      onData: (loaded) => loaded,
      onError: (error, stackTrace) {
        print("Firestore Error: $error");
        print(stackTrace);
        return RolesError("Failed to load role, $error");
      },
    );
  }
}