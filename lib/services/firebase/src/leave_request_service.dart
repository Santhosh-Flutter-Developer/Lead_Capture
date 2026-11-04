import 'package:flutter/material.dart';
import 'package:leadcapture/models/src/leave_request_model.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class LeaveRequestService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> createLeaveRequest({required LeaveRequestModel leaveRequest}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.leaveRequests.name}',
        leaveRequest.toMap(),
        activity: 'Leave request submitted by ${leaveRequest.employeeName} from ${leaveRequest.fromDate} to ${leaveRequest.toDate}',
      );

      return docRef.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error creating leave request: $e';
    }
  }

  static Future<void> updateLeaveRequest({
    required String uid,
    required LeaveRequestModel leaveRequest,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.leaveRequests.name}',
        uid,
        leaveRequest.toUpdateMap(),
        activity: 'Leave request for ${leaveRequest.employeeName} has been updated to ${leaveRequest.status.name}',
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error updating leave request: $e';
    }
  }

  static Future<LeaveRequestModel> getLeaveRequest({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      if (cid == null || cid.isEmpty) {
        throw 'Invalid company id';
      }

      if (uid.isEmpty) {
        throw 'Invalid leave request id';
      }

      final docRef = firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .doc(uid);

      final leaveRequestDoc = await docRef.get();

      if (!leaveRequestDoc.exists) {
        throw 'Leave request not found';
      }

      final data = leaveRequestDoc.data();
      if (data == null) {
        throw 'Leave request data is empty';
      }

      return LeaveRequestModel.fromMap(leaveRequestDoc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("getLeaveRequest error: $e\n$st");
      throw 'Error loading leave request: $e';
    }
  }

  static Future<List<LeaveRequestModel>> getAllLeaveRequests() async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint("Total Leave Request Docs: ${querySnapshot.docs.length}");

      List<LeaveRequestModel> leaveRequests = querySnapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.id, doc.data());
      }).toList();

      return leaveRequests;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leave requests: $e';
    }
  }

  static Future<List<LeaveRequestModel>> getLeaveRequestsByEmployee(String employeeId) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint("Total Leave Request Docs for employee $employeeId: ${querySnapshot.docs.length}");

      List<LeaveRequestModel> leaveRequests = querySnapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.id, doc.data());
      }).toList();

      return leaveRequests;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leave requests: $e';
    }
  }

  static Future<List<LeaveRequestModel>> getLeaveRequestsByStatus(LeaveStatus status) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint("Total Leave Request Docs with status ${status.name}: ${querySnapshot.docs.length}");

      List<LeaveRequestModel> leaveRequests = querySnapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.id, doc.data());
      }).toList();

      return leaveRequests;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leave requests: $e';
    }
  }

  static Future<List<LeaveRequestModel>> getLeaveRequestsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .where('fromDate', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('fromDate', isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
          .orderBy('fromDate', descending: true)
          .get();

      debugPrint("Total Leave Request Docs in date range: ${querySnapshot.docs.length}");

      List<LeaveRequestModel> leaveRequests = querySnapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.id, doc.data());
      }).toList();

      return leaveRequests;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leave requests: $e';
    }
  }

  static Future<void> deleteLeaveRequest({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leaveRequests.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();

      var employeeName = data['employeeName'] != null ? data['employeeName'] as String : 'Employee';

      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: 'Leave request for $employeeName has been deleted',
        description: 'User has deleted an entry in ${Collections.leaveRequests.name}',
        collection: '${Collections.users.name}/$cid/${Collections.leaveRequests.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting leave request: $e\n$st");
      throw 'Error deleting leave request: $e';
    }
  }

  static Future<void> approveLeaveRequest({
    required String uid,
    required String approvedBy,
    required String approvedByName,
  }) async {
    try {
      var leaveRequest = await getLeaveRequest(uid: uid);
      
      var updatedRequest = leaveRequest.copyWith(
        status: LeaveStatus.approved,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        approvedAt: DateTime.now(),
      );

      await updateLeaveRequest(uid: uid, leaveRequest: updatedRequest);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error approving leave request: $e\n$st");
      throw 'Error approving leave request: $e';
    }
  }

  static Future<void> rejectLeaveRequest({
    required String uid,
    required String approvedBy,
    required String approvedByName,
    required String rejectionReason,
  }) async {
    try {
      var leaveRequest = await getLeaveRequest(uid: uid);
      
      var updatedRequest = leaveRequest.copyWith(
        status: LeaveStatus.rejected,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        approvedAt: DateTime.now(),
        rejectionReason: rejectionReason,
      );

      await updateLeaveRequest(uid: uid, leaveRequest: updatedRequest);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error rejecting leave request: $e\n$st");
      throw 'Error rejecting leave request: $e';
    }
  }
}
