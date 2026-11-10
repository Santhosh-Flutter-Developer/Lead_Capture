import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Projects – backed by projects.php (no Firestore). A project needs an
/// associated deal (`deal_id`) on the server.
class ProjectService {
  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e\n$st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static String? _d(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _body(ProjectModel p) => {
    'project_name': p.projectName,
    'project_code': p.projectCode ?? '',
    'project_description': p.projectDescription,
    'client_id': p.clientId ?? '',
    'deal_id': p.dealId ?? '',
    'category': p.category ?? '',
    'project_owner': p.projectOwner,
    'team_lead': p.teamLead,
    'members': p.members,
    'start_date': _d(p.startDate),
    'end_date': _d(p.endDate),
    'deadline': _d(p.deadline),
    'tags': p.tags ?? '',
  };

  static Future<bool> checkProjectCodeExists({required String code, String? uid}) async {
    try {
      final c = code.trim().toLowerCase();
      if (c.isEmpty) return false;
      final all = await getAllProjects();
      return all.any((p) => p.uid != uid && (p.projectCode ?? '').trim().toLowerCase() == c);
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return false;
    }
  }

  static Future<void> createProject({required ProjectModel project}) async {
    try {
      (await ProjectsApiService.call('create', _body(project))).ensureSuccess();
      ApiLive.changed('projects');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editProject({required String uid, required ProjectModel project}) async {
    try {
      (await ProjectsApiService.call('update', {'uid': uid, ..._body(project)})).ensureSuccess();
      ApiLive.changed('projects');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<ProjectModel> getProject({required String uid}) async {
    try {
      final res = (await ProjectsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.project(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<ProjectModel>> getAllProjects() async {
    try {
      final res = (await ProjectsApiService.call('list')).ensureSuccess();
      return res.dataList.map((r) => CrmMappers.project(Js.m(r))).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server blocks deletion while tasks/tickets reference the project
  /// and returns the reason, so no pre-check is needed.
  static Future<bool> isProjectAssigned(String uid) async => false;

  static Future<void> deleteProject({required String uid}) async {
    try {
      (await ProjectsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'projects', 'trash'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> restoreProject(ProjectModel project) async {
    throw 'Restoring a deleted project is not supported by the server yet.';
  }

  static Future<int> getUserProjectsCount({required String userId}) async {
    final all = await getAllProjects();
    return all
        .where((p) => p.projectOwner == userId || p.teamLead == userId || p.members.contains(userId))
        .length;
  }
}
