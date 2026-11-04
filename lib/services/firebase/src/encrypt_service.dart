import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';

class EncryptService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void encryptAdmin() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.admins.name)
        .get();

    for (var i in docs.docs) {
      var adminModel = AdminModel.fromMap(i.id, i.data());
      await AdminService.updateAdmin(
        id: adminModel.uid ?? '',
        data: adminModel,
      );
    }
  }

  void encryptpRole() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.roles.name)
        .get();

    for (var i in docs.docs) {
      var roleModel = RoleModel.fromMap(i.id, i.data());
      await RoleService.editRole(uid: roleModel.uid ?? '', role: roleModel);
    }
  }

  void encryptDesignation() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.designations.name)
        .get();

    for (var i in docs.docs) {
      var designationModel = DesignationModel.fromMap(i.id, i.data());
      await DesignationService.editDesignation(
        uid: designationModel.uid ?? '',
        designation: designationModel,
      );
    }
  }

  void encryptDepartment() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.departments.name)
        .get();

    for (var i in docs.docs) {
      var departmentModel = DepartmentModel.fromMap(i.id, i.data());
      await DepartmentService.editDepartment(
        uid: departmentModel.uid ?? '',
        department: departmentModel,
      );
    }
  }

  void encryptSubDepartment() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.subDepartments.name)
        .get();

    for (var i in docs.docs) {
      var subDepartmentModel = SubDepartmentModel.fromMap(i.id, i.data());
      await SubDepartmentService.editSubDepartment(
        uid: subDepartmentModel.uid ?? '',
        subDepartment: subDepartmentModel,
      );
    }
  }

  void encryptEmployee() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.employees.name)
        .get();

    for (var i in docs.docs) {
      var employeeModel = EmployeeModel.fromMap(i.id, i.data());
      await EmployeeService.editEmployee(
        uid: employeeModel.uid ?? '',
        employee: employeeModel,
      );
    }
  }

  void encryptLeadCategory() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leadCategory.name)
        .get();

    for (var i in docs.docs) {
      var leadCategoryModel = LeadCategoryModel.fromMap(i.id, i.data());
      await LeadCategoryService.editLeadCategory(
        uid: leadCategoryModel.uid ?? '',
        leadCategory: leadCategoryModel,
      );
    }
  }

  void encryptLeadStatus() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leadStatus.name)
        .get();

    for (var i in docs.docs) {
      var leadStatusModel = LeadStatusModel.fromMap(i.id, i.data());
      await LeadStatusService.editLeadStatus(
        uid: leadStatusModel.uid ?? '',
        leadStatus: leadStatusModel,
      );
    }
  }

  void encryptDealStatus() async {
    var cid = await Spdb.getCid();

    var docs = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.dealStatus.name)
        .get();

    for (var i in docs.docs) {
      var dealStatusModel = DealStatusModel.fromMap(i.id, i.data());
      await DealStatusService.editDealStatus(
        uid: dealStatusModel.uid ?? '',
        dealStatus: dealStatusModel,
      );
    }
  }
}
