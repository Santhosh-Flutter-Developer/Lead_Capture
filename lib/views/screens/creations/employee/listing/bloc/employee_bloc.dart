import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'employee_event.dart';
part 'employee_state.dart';

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
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
    await emit.forEach<List<EmployeeModel>>(
      ApiLive.watch({'employee', 'role', 'designation', 'department', 'sub_department'}, () async {
        await ApiLookup.ensure();
        final res = (await EmployeesApiService.list(userType: 'employee')).ensureSuccess();
        allEmployees = res.dataList.map((e) => ApiMappers.employee(Js.m(e))).toList();
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
    // Re-fetched automatically via ApiLive
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
      await emit.forEach<List<UserRowModel>>(
        ApiLive.watch({'employee', 'admin', 'role', 'designation', 'department', 'sub_department'}, () async {
          await ApiLookup.ensure();
          final res = (await EmployeesApiService.list()).ensureSuccess();
          final rows = res.dataList.map(Js.m).toList();
          final admins = rows.where(ApiMappers.isAdminRow).map((r) => ApiMappers.admin(r).toUserRowModel());
          final emps = rows.where((r) => !ApiMappers.isAdminRow(r)).map((r) => ApiMappers.employee(r).toUserRowModel());
          return [...admins, ...emps];
        }),
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
