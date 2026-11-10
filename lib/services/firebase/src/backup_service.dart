import '/models/models.dart';
import '/constants/constants.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Backups via settings.php `manual_backup`.
/// The server writes a JSON snapshot (leads, deals, tasks, projects, clients,
/// settings) under uploads/backups and returns its filename/size. There is no
/// list/download/delete endpoint, so snapshots made in this session are kept
/// in [BackupTrigger.sessionBackups].
class BackupTrigger {
  static final List<BackupModel> sessionBackups = [];

  BackupTrigger();

  /// Runs a server backup and returns the created file name.
  /// [paths]/[subcollectionsMap]/[fileName] are ignored (kept for callers).
  Future<String> backupPaths(
    List<String> paths, {
    Map<String, List<String>>? subcollectionsMap,
    String? fileName,
  }) async {
    final res = (await SettingsApiService.call('manual_backup')).ensureSuccess();
    final d = res.dataMap;
    final name = Js.s(d['filename']);
    final uid = await Spdb.getUid() ?? '';
    final cid = await Spdb.getCid() ?? '';
    sessionBackups.insert(
      0,
      BackupModel(
        uid: name,
        intiatedBy: UserDataModel(uid: uid, name: '', userType: UserType.employee),
        parentCollectionId: cid,
        path: name,
        type: 'export',
        size: Js.i(d['size']) ?? 0,
        timestamp: Js.dt(d['timestamp']) ?? DateTime.now(),
        url: name,
      ),
    );
    return name;
  }
}
