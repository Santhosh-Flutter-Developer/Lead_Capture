/// Import is not available: the PHP API has no restore-from-backup endpoint.
class BackupImportService {
  Future<Map<String, dynamic>> importFromFile(dynamic file, {dynamic options}) =>
      Future.error('Backup import is not supported by the PHP API.');

  Future<Map<String, dynamic>> importFromJsonString(String json, {dynamic options}) =>
      Future.error('Backup import is not supported by the PHP API.');
}
