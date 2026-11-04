import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class LeadService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static String leadActivityCalendarDocId({
    required String leadUid,
    required String activityUid,
  }) {
    return 'lead_${leadUid}_activity_$activityUid';
  }

  /// Builds a normalized set of dedupe keys from raw field values: email,
  /// mobile, and lead-name+company-name as a fallback so leads without an
  /// email or mobile can still be matched. This is the single source of
  /// truth for duplicate matching, shared by manual create, quick-add,
  /// and bulk import (see LeadUpload's _duplicateKeysForRow).
  ///
  /// A Master Client can have any number of leads, so email / mobile no
  /// longer identify a duplicate (they belong to the client). Only the same
  /// lead name under the same client (or company name) counts. [email] and
  /// [mobile] are accepted for backwards compatibility and ignored.
  static List<String> duplicateKeysFor({
    String? email,
    String? mobile,
    String? leadName,
    String? companyName,
    String? clientId,
  }) {
    // Lead names are not unique: the same name can be used again, even for
    // the same client, so no key is produced and nothing counts as a
    // duplicate.
    return <String>[];
  }

  static List<String> duplicateKeysForLead(LeadModel lead) =>
      duplicateKeysFor(
        leadName: lead.leadName,
        companyName: lead.companyName,
        clientId: lead.clientId,
      );

  /// Returns true if [lead] matches an existing lead by email, mobile,
  /// or lead-name+company-name. Pass [existingLeads] to reuse an
  /// already-fetched list (e.g. during bulk import) and avoid refetching
  /// all leads on every call.
  static Future<bool> isDuplicateLead({
    required LeadModel lead,
    List<LeadModel>? existingLeads,
    String? excludeUid,
  }) async {
    final leads = existingLeads ?? await getAllLeads();
    final existingKeys = <String>{
      for (final l in leads)
        if (l.uid != excludeUid) ...duplicateKeysForLead(l),
    };
    final newKeys = duplicateKeysForLead(lead);
    return newKeys.any(existingKeys.contains);
  }

  static Future<String> createLead({
    required LeadModel lead,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      if (!skipDuplicateCheck) {
        final isDuplicate = await isDuplicateLead(lead: lead);
        if (isDuplicate) {
          throw 'This lead already exists for this client (same lead name).';
        }
      }

      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      // Ensure the creator is in workflow
      if (uid != null && !lead.workflow.contains(uid)) {
        lead.workflow.add(uid);
      }

      // Save lead to Firestore
      final userDoc = firebase.users.doc(cid);
      final leadsRef = userDoc.collection(Collections.leads.name);

      // Generate lead number if not provided
      int leadNumber = lead.leadNumber ?? 1;
      var lastLeadSnapshot = await leadsRef
          .orderBy('leadNumber', descending: true)
          .limit(1)
          .get();
      if (lastLeadSnapshot.docs.isNotEmpty) {
        leadNumber =
            (lastLeadSnapshot.docs.first.data()['leadNumber'] ?? 0) + 1;
      }

      var leadData = lead.toMap();
      leadData['leadNumber'] = leadNumber;
      leadData.remove('uid');

      var leadDoc = await leadsRef.add(leadData);

      await addLeadHistory(leadUid: leadDoc.id, action: 'Lead Created');

      // Who should be notified: an employee-created lead notifies the
      // creator + every admin; an admin-created lead notifies admins only.
      List<String> toUids = await NotificationRecipientService.forRecord(
        createdBy: lead.createdBy,
      );
      List<String> fcmIds = [];

      for (var i in toUids) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Lead : ${lead.leadName}',
        body: 'New lead created by ${user.name}',
        createdAt: DateTime.now(),
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.lead,
        payload: {'leadId': leadDoc.id},
      );

      await PostNotificationService.sendNotification(model: notif);

      return leadDoc.id;
    } catch (e, st) {
      debugPrint("Error creating lead: $e\n$st");
      await ErrorService.recordError(e, st);
      if (e is String && e.startsWith('This lead already exists')) {
        rethrow;
      }
      throw 'Error creating lead: $e';
    }
  }

  static Future<void> updateLead({
    required String uid,
    required LeadModel lead,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      var cid = await Spdb.getCid();

      if (!skipDuplicateCheck) {
        final isDuplicate = await isDuplicateLead(
          lead: lead,
          excludeUid: uid,
        );
        if (isDuplicate) {
          throw 'This lead already exists for this client (same lead name).';
        }
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.leads.name}',
        uid,
        lead.toUpdateMap(),
        activity: '${lead.leadName} has been updated',
      );
      await addLeadHistory(leadUid: uid, action: 'Lead Updated');

      List<String> users = lead.workflow.toSet().toList();

      users.add(lead.createdBy.uid);
      if (lead.clientId != null) users.add(lead.clientId!);

      // Also notify users with lead edit/view permissions
      List<String> usersWithPermission = await RoleService.getUsersWithPermission(
        page: 'Leads',
        permissionCheck: (perm) => perm.canEdit || perm.canView,
      );
      users.addAll(usersWithPermission);

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in toUids) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Lead : ${lead.leadName}',
        body: 'Lead has been updated by ${user.name}',
        createdAt: DateTime.now(),
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.lead,
        payload: {'leadId': uid},
      );
      await PostNotificationService.sendNotification(model: notif);
    } catch (e, st) {
      debugPrint("Error updating lead: $e\n$st");
      await ErrorService.recordError(e, st);
      if (e is String && e.startsWith('This lead already exists')) {
        rethrow;
      }
      throw 'Error updating lead: $e';
    }
  }

  static Future<LeadModel> getLead({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var leadDoc = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(uid)
          .get();

      if (leadDoc.exists) {
        var leadsData = leadDoc.data();
        if (leadsData != null) {
          var leads = LeadModel.fromMap(leadDoc.id, leadsData);
          return leads;
        } else {
          throw 'Lead data is empty';
        }
      } else {
        throw 'Lead not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating lead: $e';
    }
  }

  static Future<Map<LeadStatusModel, List<LeadModel>>> getLeadByGroup({
    required List<LeadModel> leadList,
  }) async {
    try {
      List<LeadStatusModel> leadStatusList =
          await LeadStatusService.getAllLeadStatus();

      Map<LeadStatusModel, List<LeadModel>> groupedLeads = {
        for (var status in leadStatusList) status: [],
      };

      for (var lead in leadList) {
        final matchingStatus = leadStatusList.firstWhere(
          (status) => status.uid == lead.leadStatus,
          orElse: () => leadStatusList.first,
        );
        groupedLeads[matchingStatus]!.add(lead);
      }

      return groupedLeads;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error grouping leads: $e\n$st");
      throw 'Error grouping leads: $e';
    }
  }

  static Future<void> updateLeadStatus({
    required String uid,
    required String leadStatus,
    bool? leadsConverted,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final updateData = <String, dynamic>{'leadStatus': leadStatus};

      if (leadsConverted != null) {
        updateData['leadsConverted'] = leadsConverted;
      }

      await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(uid)
          .update(updateData);

      // Get lead details for notification
      final leadDoc = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(uid)
          .get();

      if (leadDoc.exists) {
        final leadData = leadDoc.data();
        final lead = LeadModel.fromMap(uid, leadData!);

        // Get the new status name
        final newStatus = await LeadStatusService.getLeadStatus(uid: leadStatus);

        // Collect workflow users for notifications
        List<String> users = lead.workflow.toSet().toList();
        users.add(lead.createdBy.uid);
        if (lead.clientId != null) users.add(lead.clientId!);

        // Also notify users with lead edit/view permissions
        List<String> usersWithPermission = await RoleService.getUsersWithPermission(
          page: 'Leads',
          permissionCheck: (perm) => perm.canEdit || perm.canView,
        );
        users.addAll(usersWithPermission);

        List<String> toUids = users.toSet().toList();
        List<String> fcmIds = [];

        for (var i in toUids) {
          fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
        }

        var user = await Spdb.getUser();

        var notif = NotificationModel(
          collectionId: await Spdb.getCid() ?? '',
          title: 'Lead : ${lead.leadName}',
          body: 'Lead status changed to ${newStatus.name} by ${user.name}',
          createdAt: DateTime.now(),
          toFcms: fcmIds,
          toUids: toUids,
          senderId: await Spdb.getUid(),
          type: NotificationType.lead,
          payload: {'leadId': uid},
        );

        await PostNotificationService.sendNotification(model: notif);
      }

      // Moving a lead to "Completed" creates its deal automatically.
      await convertIfCompleted(leadUid: uid);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating lead status: $e';
    }
  }

  static Future<void> deleteLead({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      final leadDoc = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(uid)
          .get();

      if (!leadDoc.exists) {
        throw 'Lead not found or already deleted.';
      }

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      await docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['leadName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.leads.name}',
        collection: '${Collections.users.name}/$cid/${Collections.leads.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );

      // Notify users with lead delete/view permissions
      List<String> usersWithPermission = await RoleService.getUsersWithPermission(
        page: 'Leads',
        permissionCheck: (perm) => perm.canDelete || perm.canView,
      );

      if (usersWithPermission.isNotEmpty) {
        List<String> fcmIds = [];
        for (var i in usersWithPermission) {
          fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
        }

        var user = await Spdb.getUser();
        var notif = NotificationModel(
          collectionId: await Spdb.getCid() ?? '',
          title: 'Lead : ${data['leadName'] ?? 'N/A'}',
          body: 'Lead has been deleted by ${user.name}',
          createdAt: DateTime.now(),
          toFcms: fcmIds,
          toUids: usersWithPermission,
          senderId: await Spdb.getUid(),
          type: NotificationType.lead,
          payload: {'leadId': uid},
        );

        await PostNotificationService.sendNotification(model: notif);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting lead: $e\n$st");
      throw 'Error deleting lead: $e';
    }
  }

  static Future<void> restoreLead(LeadModel lead) async {
    try {
      final firebase = FirebaseConfig();
      final cid = await Spdb.getCid();

      await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(lead.uid)
          .set(lead.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// True when [statusUid] is the "Completed" stage (the final status, or any
  /// status literally named "Completed"). Reaching it converts a lead to a deal.
  static Future<bool> isConvertStatus(String statusUid) async {
    if (statusUid.isEmpty) return false;
    try {
      final status = await LeadStatusService.getLeadStatus(uid: statusUid);
      return status.isFinal || status.lowercaseName.trim() == 'completed';
    } catch (_) {
      return false;
    }
  }

  /// Converts the lead to a deal when its current status is "Completed" and it
  /// has not been converted yet. Returns true if a deal was created.
  static Future<bool> convertIfCompleted({required String leadUid}) async {
    final lead = await getLead(uid: leadUid);
    if (lead.leadsConverted || (lead.dealId ?? '').isNotEmpty) return false;
    if (!await isConvertStatus(lead.leadStatus)) return false;
    await convertLeadToDeal(lead: lead);
    return true;
  }

  /// Creates a Deal in the "New" stage from [lead] (client, value, project
  /// name/description, notes, attachments) and links the two. Safe to call
  /// twice: an already-converted lead returns its existing deal id.
  static Future<String?> convertLeadToDeal({required LeadModel lead}) async {
    try {
      final cid = await Spdb.getCid();

      if (cid == null || lead.uid == null) {
        throw "Missing cid or lead UID";
      }
      if ((lead.dealId ?? '').isNotEmpty) return lead.dealId;

      // Guard against two overlapping conversions of the same lead (double
      // drag / double tap / two code paths) creating two deals. The first
      // caller takes the lock inside a transaction; later callers stop.
      final leadRef = firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(lead.uid);
      if (!_converting.add(lead.uid!)) return null;
      var locked = false;
      try {
        locked = await firestore.runTransaction<bool>((tx) async {
          final snap = await tx.get(leadRef);
          final data = snap.data() ?? <String, dynamic>{};
          final now = DateTime.now().millisecondsSinceEpoch;
          final lockAt = data['convertLock'];
          // A lock older than 2 minutes is a crashed attempt: ignore it.
          final lockedNow = lockAt is int && now - lockAt < 120000;
          final done =
              data['leadsConverted'] == true ||
              ((data['dealId'] as String?) ?? '').isNotEmpty ||
              lockedNow;
          if (done) return false;
          tx.update(leadRef, {'convertLock': now});
          return true;
        });
        if (!locked) {
          final fresh = await leadRef.get();
          return fresh.data()?['dealId'] as String?;
        }
        return await _createDealForLead(lead: lead, cid: cid);
      } catch (e) {
        if (locked) {
          // Let a later attempt retry.
          await leadRef.update({'convertLock': FieldValue.delete()});
        }
        rethrow;
      } finally {
        _converting.remove(lead.uid!);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error converting lead: $e\n$st");
      rethrow;
    }
  }

  static final Set<String> _converting = <String>{};

  static Future<String?> _createDealForLead({
    required LeadModel lead,
    required String cid,
  }) async {
    {
      final newStatus = await DealStatusService.getByNameOrCreate(name: 'New');
      final projectName = (lead.projectName ?? '').trim();

      final deal = DealModel(
        dealName: projectName.isNotEmpty ? projectName : lead.leadName,
        dealEmail: lead.leadEmail,
        dealValue: lead.leadValue,
        allowFollowUp: true,
        dealStatus: newStatus.uid,
        attachments: lead.attachments,
        notes: lead.notes,
        companyName: lead.companyName,
        companyWebsite: lead.companyWebsite,
        companyMobile: lead.companyMobile,
        companyCountry: lead.companyCountry,
        companyState: lead.companyState,
        companyCity: lead.companyCity,
        companyAddress: lead.companyAddress,
        companyZipCode: lead.companyZipCode,
        clientName: lead.clientName,
        clientEmail: lead.clientEmail,
        clientMobile: lead.clientMobile,
        clientGender: lead.clientGender,
        salutation: lead.salutation,
        createdBy: await Spdb.getUser(),
        workFlow: List<String>.from(lead.workflow),
        clientId: lead.clientId,
        projectName: projectName.isNotEmpty ? projectName : lead.leadName,
        projectDescription: lead.projectDescription,
        followUp: lead.followUp, // keep the same follow-up employee
        leadId: lead.uid,
      );

      final dealId = await DealService.createDeal(
        deal: deal,
        skipDuplicateCheck: true,
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(lead.uid)
          .update({
            'leadsConverted': true,
            'dealId': dealId,
            'convertLock': FieldValue.delete(),
          });
      await addLeadHistory(
        leadUid: lead.uid!,
        action: 'Lead Converted to Deal',
      );

      debugPrint("Lead ${lead.leadName} converted to deal $dealId.");
      return dealId;
    }
  }

  static Future<void> addLeadComment({
    required String leadUid,
    required LeadCommentModel comment,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) throw "Missing cid or uid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(leadUid)
          .collection('comments');

      await commentsRef.add(comment.toMap());
      await addLeadHistory(
        leadUid: leadUid,
        action: 'Comment Added: ${comment.comment}',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error adding lead comment: $e\n$st");
      rethrow;
    }
  }

  static Future<void> editLeadComment({
    required String leadUid,
    required String commentUid,
    required String commentText,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) throw "Missing cid or uid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(leadUid)
          .collection('comments')
          .doc(commentUid);

      final commentData = {'comment': commentText};

      await commentsRef.update(commentData);
      await addLeadHistory(
        leadUid: leadUid,
        action: 'Comment Updated: $commentText',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error updating lead comment: $e\n$st");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getLeadComments({
    required String leadUid,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "Missing cid";

      final commentsRef = firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(leadUid)
          .collection('comments');

      final querySnapshot = await commentsRef
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error fetching lead comments: $e\n$st");
      rethrow;
    }
  }

  static Future<void> deleteLeadComment({
    required String leadUid,
    required String commentUid,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "Missing cid";

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(leadUid)
          .collection('comments')
          .doc(commentUid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting lead comment: $e\n$st");
      rethrow;
    }
  }

  static Future<List<LeadModel>> getAllLeads() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .get();

      List<LeadModel> leads = querySnapshot.docs.map((doc) {
        return LeadModel.fromMap(doc.id, doc.data());
      }).toList();

      leads.sort((a, b) => a.leadName.compareTo(b.leadName));

      return FollowUpAccess.filterVisible(leads, (l) => l.followUp);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching projects: $e';
    }
  }

  static Future<void> addLeadHistory({
    required String leadUid,
    required String action,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      final historyRef = firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(leadUid)
          .collection('history');

      final history = LeadHistoryModel(
        userId: user.uid,
        updateDisposition: action,
      );

      await historyRef.add(history.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error adding lead history: $e\n$st");
      rethrow;
    }
  }

  static Future<void> backfillLeadActivitiesToCalendar() async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      final leadsSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .get();

      for (final leadDoc in leadsSnapshot.docs) {
        final activitiesSnapshot = await leadDoc.reference
            .collection('activities')
            .get();

        for (final activityDoc in activitiesSnapshot.docs) {
          final activity = LeadActivityModel.fromMap(
            activityDoc.id,
            activityDoc.data(),
          );

          final calendarDocId = leadActivityCalendarDocId(
            leadUid: leadDoc.id,
            activityUid: activityDoc.id,
          );

          final eventModel = EventModel(
            eventName: activity.title,
            eventDateTime: activity.scheduledAt,
            eventEndDateTime: activity.scheduledAt.add(
              const Duration(hours: 1),
            ),
            eventDescription: activity.description.isNotEmpty
                ? activity.description
                : 'Lead activity scheduled',
            eventRepeatType: EventRepeatType.none,
            eventAttendes: const [],
            createdBy: user,
            completed: activity.completed,
          );

          await CommonService.add(
            '${Collections.users.name}/$cid/${Collections.events.name}',
            eventModel.toMap(),
            docId: calendarDocId,
          );
        }
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('Error backfilling lead activities to calendar: $e\n$st');
    }
  }

  static Future<int> getUserLeadsCount({required String userId}) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .where('workflow', arrayContains: userId)
          .get();

      return snapshot.docs.length;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting user lead count: $e';
    }
  }
}