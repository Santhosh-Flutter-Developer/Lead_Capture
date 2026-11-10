import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Project updations – backed by project_updations.php (no Firestore).
/// `project_id` is the uid of the (completed) deal the updation belongs to.
class ProjectUpdationService {
  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e\n$st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _body(ProjectUpdationModel u) => {
    'project_id': u.projectId,
    'project_name': u.projectName,
    'client_id': u.clientId ?? '',
    'company_name': u.companyName ?? '',
    'contact_name': u.contactName ?? '',
    'contact_mobile': u.contactMobile ?? '',
    'title': u.title,
    'description': u.description,
    'requested_date': _d(u.requestedDate),
    'status': u.status.name,
    'value': u.value ?? 0,
    'deadline': u.deadline == null ? null : _d(u.deadline!),
    'assignee_id': u.assigneeId ?? u.followUp ?? '',
    'assignee_name': u.assigneeName ?? '',
    'notes': u.notes,
    'attachment_ids': CrmMappers.attachmentIds(u.attachments),
  };

  static Future<String> createUpdation({required ProjectUpdationModel updation}) async {
    try {
      final res = (await ProjectUpdationsApiService.call('create', _body(updation))).ensureSuccess();
      ApiLive.changed('updations');
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> updateUpdation({
    required String uid,
    required ProjectUpdationModel updation,
  }) async {
    try {
      final current = await getUpdation(uid: uid);
      final keep = updation.attachments.map((f) => ApiAttachments.idOf(f.url)).toSet();
      for (final old in current.attachments) {
        final id = ApiAttachments.idOf(old.url);
        if (id != null && !keep.contains(id)) {
          await ProjectUpdationsApiService.call('delete_attachment', {'id': id});
        }
      }
      (await ProjectUpdationsApiService.call('update', {'uid': uid, ..._body(updation)})).ensureSuccess();
      ApiLive.changed('updations');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> updateStatus({required String uid, required UpdationStatus status}) async {
    try {
      (await ProjectUpdationsApiService.call('update_status', {'uid': uid, 'status': status.name})).ensureSuccess();
      ApiLive.changed('updations');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<ProjectUpdationModel> getUpdation({required String uid}) async {
    try {
      final res = (await ProjectUpdationsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.updation(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<ProjectUpdationModel>> getAllUpdations({String? projectId}) async {
    try {
      final res = (await ProjectUpdationsApiService.call('list', {
        if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
      })).ensureSuccess();
      final list = res.dataList.map((r) => CrmMappers.updation(Js.m(r))).toList();
      list.sort((a, b) => (b.updationNumber ?? 0).compareTo(a.updationNumber ?? 0));
      return FollowUpAccess.filterVisible(list, (u) => u.followUp);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> deleteUpdation({required String uid}) async {
    try {
      (await ProjectUpdationsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'updations', 'trash'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> restoreUpdation(ProjectUpdationModel updation) async {
    throw 'Restoring a deleted updation is not supported by the server yet.';
  }
}
