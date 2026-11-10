import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Deals – backed by deals.php (no Firestore). Server handles logging,
/// notifications, lock rules and lead→deal conversion.
class DealService {
  static List<String> duplicateKeysFor({
    String? email,
    String? mobile,
    String? dealName,
    String? companyName,
    String? clientId,
  }) => <String>[];

  static List<String> duplicateKeysForDeal(DealModel deal) => <String>[];

  static Future<bool> isDuplicateDeal({
    required DealModel deal,
    List<DealModel>? existingDeals,
    String? excludeUid,
  }) async => false;

  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$prefix: $e\n$st');
    if (e is ApiException) throw e.message;
    if (e is String) throw e;
    throw '$prefix: $e';
  }

  static Map<String, dynamic> _body(DealModel d) => {
    'deal_name': d.dealName,
    'project_name': (d.projectName ?? '').isEmpty ? d.dealName : d.projectName,
    'deal_email': d.dealEmail,
    'client_id': d.clientId ?? '',
    'company_name': d.companyName ?? '',
    'client_name': d.clientName ?? '',
    'client_mobile': d.clientMobile ?? '',
    'deal_value': d.dealValue,
    'allow_follow_up': d.allowFollowUp ? 1 : 0,
    'follow_up': d.followUp ?? '',
    'deal_status_id': (d.dealStatus ?? '').isEmpty ? null : d.dealStatus,
    'notes': d.notes,
    'project_description': d.projectDescription ?? '',
    'attachment_ids': CrmMappers.attachmentIds(d.attachments),
  };

  static Future<String> createDeal({
    required DealModel deal,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      final res = (await DealsApiService.call('create', _body(deal))).ensureSuccess();
      ApiLive.changed('deals');
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      _fail('Error creating deal', e, st);
    }
  }

  static Future<void> updateDeal({
    required String uid,
    required DealModel deal,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      final current = await getDeal(uid: uid);
      final keep = deal.attachments.map((f) => ApiAttachments.idOf(f.url)).toSet();
      for (final old in current.attachments) {
        final id = ApiAttachments.idOf(old.url);
        if (id != null && !keep.contains(id)) {
          await DealsApiService.call('delete_attachment', {'id': id});
        }
      }
      (await DealsApiService.call('update', {'uid': uid, ..._body(deal)})).ensureSuccess();
      ApiLive.changed({'deals', 'deal_$uid'});
    } catch (e, st) {
      _fail('Error updating deal', e, st);
    }
  }

  static Future<DealModel> getDeal({required String uid}) async {
    try {
      final res = (await DealsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.deal(res.dataMap);
    } catch (e, st) {
      _fail('Error getting deal', e, st);
    }
  }

  static Future<Map<DealStatusModel, List<DealModel>>> getDealByGroup({
    required List<DealModel> dealList,
  }) async {
    try {
      final statuses = await DealStatusService.getAllDealStatus();
      final grouped = <DealStatusModel, List<DealModel>>{
        for (final s in statuses) s: [],
      };
      if (statuses.isEmpty) return grouped;
      for (final d in dealList) {
        final match = statuses.firstWhere(
          (s) => s.uid == d.dealStatus,
          orElse: () => statuses.first,
        );
        grouped[match]!.add(d);
      }
      return grouped;
    } catch (e, st) {
      _fail('Error grouping deals', e, st);
    }
  }

  static Future<void> updateDealStatus({
    required String uid,
    required String dealStatus,
  }) async {
    try {
      (await DealsApiService.call('update_status', {'uid': uid, 'status_id': dealStatus})).ensureSuccess();
      ApiLive.changed({'deals', 'projects'});
    } catch (e, st) {
      _fail('Error updating deal status', e, st);
    }
  }

  /// Admin only (server enforced).
  static Future<void> toggleLock({required String uid, required bool locked}) async {
    try {
      (await DealsApiService.call('toggle_lock', {'uid': uid, 'is_locked': locked ? 1 : 0})).ensureSuccess();
      ApiLive.changed('deals');
    } catch (e, st) {
      _fail('Error locking deal', e, st);
    }
  }

  static Future<void> deleteDeal({required String uid}) async {
    try {
      (await DealsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'deals', 'trash'});
    } catch (e, st) {
      _fail('Error deleting deal', e, st);
    }
  }

  /// deals.php has no restore action (settings.php trash may – see TrashService).
  static Future<void> restoreDeal(DealModel deal) async {
    throw 'Restoring a deleted deal is not supported by the server yet.';
  }

  static Future isDealStatusAssigned(String s) async {}

  static Future<void> deleteDealComment({
    required String dealUid,
    required String commentUid,
  }) async {
    try {
      (await DealsApiService.call('delete_comment', {'comment_uid': commentUid})).ensureSuccess();
      ApiLive.changed('deal_$dealUid');
    } catch (e, st) {
      _fail('Error deleting comment', e, st);
    }
  }

  static Future<void> addDealComment({
    required String dealUid,
    required DealCommentModel commentText,
  }) async {
    try {
      (await DealsApiService.call('add_comment', {'deal_uid': dealUid, 'comment': commentText.comment})).ensureSuccess();
      ApiLive.changed('deal_$dealUid');
    } catch (e, st) {
      _fail('Error adding comment', e, st);
    }
  }

  static Future<void> editDealComment({
    required String dealUid,
    required String commentUid,
    required String commentText,
  }) async {
    throw 'Editing comments is not supported by the server yet.';
  }

  static Future<List<Map<String, dynamic>>> getDealComments({required String dealUid}) async {
    final res = (await DealsApiService.call('get', {'uid': dealUid})).ensureSuccess();
    return Js.mapList(res.dataMap['comments'])
        .map((c) => {
              'uid': Js.s(c['uid']),
              'comment': Js.s(c['comment']),
              'userId': Js.s(c['user_uid']),
              'createdAt': (Js.dt(c['created_at']) ?? DateTime.now()).millisecondsSinceEpoch,
            })
        .toList();
  }

  static Future<Map<String, dynamic>> _detail(String uid) async =>
      (await DealsApiService.call('get', {'uid': uid})).ensureSuccess().dataMap;

  static Future<List<DealCommentModel>> getComments(String dealUid) async =>
      Js.mapList((await _detail(dealUid))['comments']).map(CrmMappers.dealComment).toList();

  static Future<List<DealHistoryModel>> getHistory(String dealUid) async =>
      Js.mapList((await _detail(dealUid))['history']).map(CrmMappers.dealHistory).toList();

  static Future<List<DealActivityModel>> getActivities(String dealUid) async =>
      Js.mapList((await _detail(dealUid))['activities']).map(CrmMappers.dealActivity).toList();

  static Future<void> addActivity({
    required String dealUid,
    required DealActivityModel activity,
  }) async {
    try {
      (await DealsApiService.call('add_activity', {
        'deal_uid': dealUid,
        'title': activity.title,
        'type': activity.type.name,
        'description': activity.description,
        'scheduled_at': activity.scheduledAt.toIso8601String(),
      })).ensureSuccess();
      ApiLive.changed({'deal_$dealUid', 'calendar'});
    } catch (e, st) {
      _fail('Error adding activity', e, st);
    }
  }

  /// The server writes deal history itself.
  static Future<void> addDealHistory({
    required String dealUid,
    required String action,
  }) async {}

  static Future<List<DealModel>> getAllDeals() async {
    try {
      final res = (await DealsApiService.call('list')).ensureSuccess();
      final deals = res.dataList.map((r) => CrmMappers.deal(Js.m(r))).toList();
      deals.sort((a, b) => a.dealName.compareTo(b.dealName));
      return FollowUpAccess.filterVisible(deals, (d) => d.followUp);
    } catch (e, st) {
      _fail('Error fetching deals', e, st);
    }
  }

  static Future<int> getUserDealsCount({required String userId}) async {
    final all = await getAllDeals();
    return all.where((d) => d.workFlow.contains(userId) || d.followUp == userId).length;
  }

  static Future<List<DealModel>> _completed(List<DealModel> deals) async {
    final statuses = await DealStatusService.getAllDealStatus();
    final done = statuses
        .where((s) => s.isFinal || s.lowercaseName == 'completed')
        .map((s) => s.uid)
        .toSet();
    return deals.where((d) => d.isLocked || done.contains(d.dealStatus)).toList();
  }

  static Future<List<DealModel>> getCompletedDealsByClient({required String clientId}) async {
    try {
      final all = await getAllDeals();
      final r = await _completed(all.where((d) => d.clientId == clientId).toList());
      r.sort((a, b) => (a.projectName ?? a.dealName).toLowerCase().compareTo((b.projectName ?? b.dealName).toLowerCase()));
      return r;
    } catch (e, st) {
      _fail('Error fetching completed deals', e, st);
    }
  }

  static Future<List<DealModel>> getAllCompletedDeals() async {
    try {
      return await _completed(await getAllDeals());
    } catch (e, st) {
      _fail('Error fetching completed deals', e, st);
    }
  }

  /// Next upcoming follow-up date per deal uid (one `get` per deal).
  static Future<Map<String, DateTime>> getNextFollowUps(List<String> dealUids) async {
    final result = <String, DateTime>{};
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await Future.wait(dealUids.map((id) async {
        final acts = await getActivities(id);
        DateTime? next;
        for (final a in acts) {
          if (a.type != DealActivityType.followUp || a.completed) continue;
          if (a.scheduledAt.isBefore(today)) continue;
          if (next == null || a.scheduledAt.isBefore(next)) next = a.scheduledAt;
        }
        if (next != null) result[id] = next;
      }));
    } catch (e) {
      debugPrint('getNextFollowUps: $e');
    }
    return result;
  }
}
