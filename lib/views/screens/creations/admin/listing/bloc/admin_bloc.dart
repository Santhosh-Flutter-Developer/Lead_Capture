import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

part 'admin_event.dart';
part 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  AdminBloc() : super(AdminLoading()) {
    on<StreamAdmins>(_streamAdmins);
    on<AddAdmin>(_addAdmin);
    on<UpdateAdmin>(_updateAdmin);
    on<DeleteAdmin>(_deleteAdmin);
  }

  /// STREAM ADMINS LIVE
  Future<void> _streamAdmins(
    StreamAdmins event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());

    try {
      var cid = await Spdb.getCid();

      await emit.forEach<List<AdminModel>>(
        firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.admins.name)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => AdminModel.fromMap(doc.id, doc.data()))
                  .toList(),
            ),
        onData: (admins) => AdminLoaded(admins),
        onError: (e, st) => AdminError("Failed to load admins: $e"),
      );
    } catch (e, st) {
      debugPrint("$e, $st");
      emit(AdminError("Error streaming admins: $e"));
    }
  }

  /// ADD ADMIN
  Future<void> _addAdmin(AddAdmin event, Emitter<AdminState> emit) async {
    try {
      await AdminService.createAdmin(admin: event.admin);
      emit(const AdminSuccess("Admin added successfully"));
    } catch (e, st) {
      debugPrint("$e, $st");
      emit(AdminError("Failed to add admin: $e"));
    }
  }

  /// UPDATE ADMIN
  Future<void> _updateAdmin(UpdateAdmin event, Emitter<AdminState> emit) async {
    try {
      await AdminService.updateAdmin(
        id: event.uid,
        data: AdminModel.fromMap(event.uid, event.updatedData),
      );
      add(StreamAdmins());
      emit(const AdminSuccess("Admin updated successfully"));
    } catch (e, st) {
      debugPrint("$e, $st");
      emit(AdminError("Failed to update admin: $e"));
    }
  }

  Future<void> _deleteAdmin(DeleteAdmin event, Emitter<AdminState> emit) async {
    try {
      await AdminService.deleteAdmin(uid: event.uid);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('Delete admin failed: $e');
    }
  }

  // Future<void> _deleteAdmin(DeleteAdmin event, Emitter<AdminState> emit) async {
  //   try {
  //     await AdminService.deleteAdmin(uid: event.uid);
  //     emit(const AdminSuccess("Admin deleted successfully"));
  //     add(StreamAdmins());
  //   } catch (e, st) {
  //     debugPrint("$e, $st");
  //     emit(AdminError("Failed to delete admin: $e"));
  //   }
  // }
}
