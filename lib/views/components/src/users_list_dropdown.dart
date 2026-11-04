import 'package:flutter/material.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/constants/src/enum.dart';

class UsersListDropdown extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? Function(dynamic)? validator;
  final Function(List<dynamic>)? onChangedList;
  final List<dynamic> initialValues;
  final bool includeCurrentUser;
  final bool includeGroups;
  final bool includeDepartments;
  const UsersListDropdown({
    super.key,
    required this.label,
    this.isRequired = false,
    this.validator,
    this.onChangedList,
    this.initialValues = const [],
    this.includeCurrentUser = true,
    this.includeGroups = false,
    this.includeDepartments = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomFutureSearchableDropdown<dynamic>(
      label: label,
      isRequired: isRequired,
      validator: validator,
      initialValues: initialValues,
      asyncItems: () async {
        var admins = await AdminService.getAllAdmins();
        var employees = await EmployeeService.getAllEmployees();

        List<dynamic> result = [];

        if (!includeCurrentUser) {
          var currentUser = await Spdb.getUser();
          if (currentUser.userType == UserType.admin) {
            admins = admins
                .where((admin) => admin.uid != currentUser.uid)
                .toList();
          } else if (currentUser.userType == UserType.employee) {
            employees = employees
                .where((employee) => employee.uid != currentUser.uid)
                .toList();
          }
        }

        result.addAll(admins);
        result.addAll(employees);

        if (includeGroups) {
          var groups = await ChatService.getChatGroups();
          result.addAll(groups);
        }

        if (includeDepartments) {
          var allDeps = await DepartmentService.getAllDepartments();
          if (allDeps.isNotEmpty) {
            for (DepartmentModel i in allDeps) {
              var depEmployees = await EmployeeService.getEmployeesByDepartment(
                depId: i.uid ?? '',
              );
              if (depEmployees.isNotEmpty) {
                var depResult = depEmployees.map((e) => e.uid).toList();
                result.add({i: depResult});
              }
            }
          }
        }

        return result;
      },
      multiSelect: true,
      itemAsString: (users) {
        if (users is AdminModel) {
          return '${users.name} (Admin)';
        } else if (users is EmployeeModel) {
          return '${users.name} (${users.employeeId})';
        } else if (users is ChatModel) {
          return '${users.title ?? ''} (${users.participants.length} Members)';
        } else if (users is Map<DepartmentModel, List<String?>>) {
          return '${users.keys.first.name} (${users.values.length})';
        }
        return "";
      },
      onChangedList: onChangedList,
    );
  }
}
