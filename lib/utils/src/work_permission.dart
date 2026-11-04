

import 'package:leadcapture/constants/src/enum.dart';
import 'package:leadcapture/utils/src/extensions.dart';

extension PermissionTypeExtension on PermissionType {
  String get label {
    switch (this) {
      case PermissionType.permission:
        return "Short Permission";
      case PermissionType.leaveFullDay:
        return "Full Day Leave";
      case PermissionType.leaveHalfDay:
        return "Half Day Leave";
      case PermissionType.workFromHome:
        return "Work From Home";
      case PermissionType.lateEntry:
        return "Late Entry";
      case PermissionType.earlyExit:
        return "Early Exit";
      // case PermissionType.onDuty:
      //   return "On Duty (OD)";
      // case PermissionType.compOff:
      //   return "Comp Off";
    }
  }

  bool get requiresTime {
    switch (this) {
      case PermissionType.leaveFullDay:
      case PermissionType.leaveHalfDay:
      case PermissionType.workFromHome:
        return false;

      case PermissionType.permission:
      case PermissionType.lateEntry:
      case PermissionType.earlyExit:
        return true;
    }
  }

  bool get hasSalaryDeduction {
    switch (this) {
      case PermissionType.workFromHome:
        return false;

      case PermissionType.permission:
      case PermissionType.leaveHalfDay:
      case PermissionType.leaveFullDay:
      case PermissionType.lateEntry:
      case PermissionType.earlyExit:
        return true;
    }
  }
}

PermissionType getPermissionType(dynamic value) {
  if (value == null) {
    return PermissionType.permission;
  }

  try {
    final decrypted = value.toString().decrypt;

    return PermissionType.values.firstWhere(
      (e) => e.name == decrypted,
      orElse: () => PermissionType.permission,
    );
  } catch (_) {
    return PermissionType.permission;
  }
}
