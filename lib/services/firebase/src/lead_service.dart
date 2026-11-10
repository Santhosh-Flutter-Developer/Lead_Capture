import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Leads – backed by leads.php (no Firestore). Notifications, activity logs,
/// history and auto-conversion to a deal are produced by the server.
///
/// Fields the PHP `leads` table does not have (company website/country/
/// state/city/address/zip, client e-mail/gender) are not persisted; see
/// MISSING_API_REQUIREMENTS.md.
class LeadService {
  static String leadActivityCalendarDocId({
    required String leadUid,
    required String activityUid,
  }) => 'lead_${leadUid}_activity_$activityUid';

  /// Lead names are not unique, nothing counts as duplicate (unchanged rule).
  static List<String> duplicateKeysFor({
    String? email,
    String? mobile,
    String? leadName,
    String? companyName,
    String? clientId,
  }) => <String>[];

  static List<String> duplicateKeysForLead(LeadModel lead) => duplicateKeysFor(
    leadName: lead.leadName,
    companyName: lead.companyName,
    clientId: lead.clientId,
  );

  static Future<bool> isDuplicateLead({
    required LeadModel lead,
    List<LeadModel>? existingLeads,
    String? excludeUid,
  }) async => false;

  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$prefix: $e\n$st');
    if (e is ApiException) throw e.message;
    if (e is String) throw e;
    throw '$prefix: $e';
  }

  static Map<String, dynamic> _body(LeadModel l) => {
    'salutation': l.salutation,
    'lead_name': l.leadName,
    'lead_email': l.leadEmail,
    'client_id': l.clientId ?? '',
    'company_name': l.companyName ?? '',
    'client_name': l.clientName ?? '',
    'client_mobile': l.clientMobile ?? '',
    'lead_source_id': (l.leadSource.uid ?? '').isEmpty ? null : l.leadSource.uid,
    'lead_category_id': l.leadCategory.isEmpty ? null : l.leadCategory,
    'lead_priority_id': l.leadPriority.isEmpty ? null : l.leadPriority,
    'lead_status_id': l.leadStatus.isEmpty ? null : l.leadStatus,
    'lead_value': l.leadValue,
    'notes': l.notes,
    'project_name': l.projectName ?? '',
    'project_description': l.projectDescription ?? '',
    'follow_up': l.followUp ?? '',
    'attachment_ids': CrmMappers.attachmentIds(l.attachments),
  };

  static Future<String> createLead({
    required LeadModel lead,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      final res = (await LeadsApiService.call('create', _body(lead))).ensureSuccess();
      ApiLive.changed({'leads', 'deals'});
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      _fail('Error creating lead', e, st);
    }
  }

  static Future<void> updateLead({
    required String uid,
    required LeadModel lead,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      // drop attachments removed in the form
      final current = await getLead(uid: uid);
      final keep = lead.attachments.map((f) => ApiAttachments.idOf(f.url)).toSet();
      for (final old in current.attachments) {
        final id = ApiAttachments.idOf(old.url);
        if (id != null && !keep.contains(id)) {
          await LeadsApiService.call('delete_attachment', {'id': id});
        }
      }
      (await LeadsApiService.call('update', {'uid': uid, ..._body(lead)})).ensureSuccess();
      ApiLive.changed({'leads', 'deals'});
    } catch (e, st) {
      _fail('Error updating lead', e, st);
    }
  }

  static Future<LeadModel> getLead({required String uid}) async {
    try {
      final res = (await LeadsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.lead(res.dataMap);
    } catch (e, st) {
      _fail('Error getting lead', e, st);
    }
  }

  static Future<Map<LeadStatusModel, List<LeadModel>>> getLeadByGroup({
    required List<LeadModel> leadList,
  }) async {
    try {
      final statuses = await LeadStatusService.getAllLeadStatus();
      final grouped = <LeadStatusModel, List<LeadModel>>{
        for (final s in statuses) s: [],
      };
      if (statuses.isEmpty) return grouped;
      for (final lead in leadList) {
        final match = statuses.firstWhere(
          (s) => s.uid == lead.leadStatus,
          orElse: () => statuses.first,
        );
        grouped[match]!.add(lead);
      }
      return grouped;
    } catch (e, st) {
      _fail('Error grouping leads', e, st);
    }
  }

  /// Server converts to a deal itself when the new status is final/"Completed".
  static Future<void> updateLeadStatus({
    required String uid,
    required String leadStatus,
    bool? leadsConverted,
  }) async {
    try {
      (await LeadsApiService.call('update_status', {'uid': uid, 'status_id': leadStatus})).ensureSuccess();
      ApiLive.changed({'leads', 'deals'});
    } catch (e, st) {
      _fail('Error updating lead status', e, st);
    }
  }

  static Future<void> deleteLead({required String uid}) async {
    try {
      (await LeadsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'leads', 'trash'});
    } catch (e, st) {
      _fail('Error deleting lead', e, st);
    }
  }

  static Future<void> restoreLead(LeadModel lead) async {
    try {
      (await LeadsApiService.call('restore', {'uid': lead.uid})).ensureSuccess();
      ApiLive.changed({'leads', 'trash'});
    } catch (e, st) {
      ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      rethrow;
    }
  }

  static Future<bool> isConvertStatus(String statusUid) async {
    if (statusUid.isEmpty) return false;
    try {
      final s = await LeadStatusService.getLeadStatus(uid: statusUid);
      return s.isFinal || s.isMoveToDeal || s.lowercaseName.trim() == 'completed';
    } catch (_) {
      return false;
    }
  }

  /// The server auto-converts on create/update/update_status; this only
  /// reports whether the lead is now converted.
  static Future<bool> convertIfCompleted({required String leadUid}) async {
    final lead = await getLead(uid: leadUid);
    return lead.leadsConverted;
  }

  /// Returns the new deal uid (leads.php convert_to_deal).
  static Future<String?> convertLeadToDeal({required LeadModel lead}) async {
    try {
      if (lead.uid == null) throw 'Missing lead UID';
      if ((lead.dealId ?? '').isNotEmpty) return lead.dealId;
      final res = (await LeadsApiService.call('convert_to_deal', {'uid': lead.uid})).ensureSuccess();
      ApiLive.changed({'leads', 'deals'});
      final d = res.dataMap;
      return Js.opt(d['deal_uid'] ?? d['uid'] ?? Js.m(d['deal'])['uid']);
    } catch (e, st) {
      _fail('Error converting lead', e, st);
    }
  }

  static Future<void> addLeadComment({
    required String leadUid,
    required LeadCommentModel comment,
  }) async {
    try {
      (await LeadsApiService.call('add_comment', {'lead_uid': leadUid, 'comment': comment.comment})).ensureSuccess();
      ApiLive.changed('lead_$leadUid');
    } catch (e, st) {
      _fail('Error adding comment', e, st);
    }
  }

  /// leads.php has no comment-edit action.
  static Future<void> editLeadComment({
    required String leadUid,
    required String commentUid,
    required String commentText,
  }) async {
    throw 'Editing comments is not supported by the server yet.';
  }

  static Future<List<Map<String, dynamic>>> getLeadComments({required String leadUid}) async {
    try {
      final res = (await LeadsApiService.call('get', {'uid': leadUid})).ensureSuccess();
      return Js.mapList(res.dataMap['comments'])
          .map((c) => {
                'uid': Js.s(c['uid']),
                'comment': Js.s(c['comment']),
                'userId': Js.s(c['user_uid']),
                'createdAt': (Js.dt(c['created_at']) ?? DateTime.now()).millisecondsSinceEpoch,
              })
          .toList();
    } catch (e, st) {
      _fail('Error fetching comments', e, st);
    }
  }

  static Future<void> deleteLeadComment({
    required String leadUid,
    required String commentUid,
  }) async {
    try {
      (await LeadsApiService.call('delete_comment', {'comment_uid': commentUid})).ensureSuccess();
      ApiLive.changed('lead_$leadUid');
    } catch (e, st) {
      _fail('Error deleting comment', e, st);
    }
  }

  // ── detail extras (comments / history / activities come with `get`) ──
  static Future<List<LeadCommentModel>> getComments(String leadUid) async {
    final res = (await LeadsApiService.call('get', {'uid': leadUid})).ensureSuccess();
    return Js.mapList(res.dataMap['comments']).map(CrmMappers.leadComment).toList();
  }

  static Future<List<LeadHistoryModel>> getHistory(String leadUid) async {
    final res = (await LeadsApiService.call('get', {'uid': leadUid})).ensureSuccess();
    return Js.mapList(res.dataMap['history']).map(CrmMappers.leadHistory).toList();
  }

  static Future<List<LeadActivityModel>> getActivities(String leadUid) async {
    final res = (await LeadsApiService.call('get', {'uid': leadUid})).ensureSuccess();
    return Js.mapList(res.dataMap['activities']).map(CrmMappers.leadActivity).toList();
  }

  static Future<void> addActivity({
    required String leadUid,
    required LeadActivityModel activity,
  }) async {
    try {
      (await LeadsApiService.call('add_activity', {
        'lead_uid': leadUid,
        'title': activity.title,
        'type': activity.type.name,
        'description': activity.description,
        'scheduled_at': activity.scheduledAt.toIso8601String(),
      })).ensureSuccess();
      ApiLive.changed({'lead_$leadUid', 'calendar'});
    } catch (e, st) {
      _fail('Error adding activity', e, st);
    }
  }

  static Future<List<LeadModel>> getAllLeads() async {
    try {
      final res = (await LeadsApiService.call('list')).ensureSuccess();
      final leads = res.dataList.map((r) => CrmMappers.lead(Js.m(r))).toList();
      leads.sort((a, b) => a.leadName.compareTo(b.leadName));
      return FollowUpAccess.filterVisible(leads, (l) => l.followUp);
    } catch (e, st) {
      _fail('Error fetching leads', e, st);
    }
  }

  /// The server writes lead history itself.
  static Future<void> addLeadHistory({
    required String leadUid,
    required String action,
  }) async {}

  static Future<void> backfillLeadActivitiesToCalendar() async {}

  static Future<int> getUserLeadsCount({required String userId}) async {
    try {
      final all = await getAllLeads();
      return all.where((l) => l.workflow.contains(userId) || l.followUp == userId).length;
    } catch (e, st) {
      _fail('Error getting user lead count', e, st);
    }
  }
}
