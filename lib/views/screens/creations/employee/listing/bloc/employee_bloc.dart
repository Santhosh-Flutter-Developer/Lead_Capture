import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'employee_event.dart';
part 'employee_state.dart';

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<EmployeeModel> allEmployees = [];

  EmployeeBloc() : super(EmployeeLoading()) {
    on<StreamEmployee>(_streamEmployees);
    on<DeleteEmployee>(_deleteEmployee);
  }

  Future<void> _streamEmployees(
    StreamEmployee event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.employees.name)
          .snapshots()
          .map((snapshot) {
            allEmployees = snapshot.docs
                .map((doc) => EmployeeModel.fromMap(doc.id, doc.data()))
                .toList();

            return allEmployees;
          }),
      onData: (employees) => EmployeeLoaded(employees),
      onError: (error, stackTrace) {
        log(stackTrace.toString());
        return EmployeeError("Failed to load employees, $error");
      },
    );
  }

  Future<void> _deleteEmployee(
  DeleteEmployee event,
  Emitter<EmployeeState> emit,
) async {
  try {
    await EmployeeService.deleteEmployee(uid: event.uid);
    // Firestore stream will auto-update the list
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    debugPrint('Delete employee failed: $e');
  }
}


  // Future<void> _deleteEmployee(
  //   DeleteEmployee event,
  //   Emitter<EmployeeState> emit,
  // ) async {
  //   try {
  //     await EmployeeService.deleteEmployee(uid: event.uid);

  //     // var updatedList = await EmployeeService.getAllEmployees();
  //     // emit(EmployeeLoaded(updatedList));
  //   } catch (e, st) {
  //     await ErrorService.recordError(e, st);
  //     emit(EmployeeError("Failed to delete employee: $e"));
  //   }
  // }
}

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  UsersBloc() : super(UsersLoading()) {
    on<StreamUsers>(_streamUsers);
      on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _streamUsers(
    StreamUsers event,
    Emitter<UsersState> emit,
  ) async {
    emit(UsersLoading());

    try {
      final cid = await Spdb.getCid();

      final employeeStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.employees.name)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => EmployeeModel.fromMap(doc.id, doc.data())
                      .toUserRowModel(),
                )
                .toList(),
          );

      final adminStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.admins.name)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) =>
                      AdminModel.fromMap(doc.id, doc.data()).toUserRowModel(),
                )
                .toList(),
          );

      await emit.forEach<List<UserRowModel>>(
        Rx.combineLatest2(
          employeeStream,
          adminStream,
          (List<UserRowModel> employees, List<UserRowModel> admins) {
            return [...admins, ...employees];
          },
        ),
        onData: (users) => UsersLoaded(users),
        onError: (e, _) => UsersError("Failed to load users: $e"),
      );
    } catch (e, _) {
      emit(UsersError("Error streaming users: $e"));
    }
  }

  Future<void> _onDeleteUser(
    DeleteUser event,
    Emitter<UsersState> emit,
  ) async {
    try {
      // 🔥 FIREBASE DELETE
      if (event.user.userType == UserType.employee) {
        await EmployeeService.deleteEmployee(uid: event.user.uid);
      } else {
        await AdminService.deleteAdmin(uid: event.user.uid);
      }

      // 🔄 REFRESH UI
      add(StreamUsers());
    } catch (e) {
      emit(UsersError("Delete failed: $e"));
    }
  }
}
