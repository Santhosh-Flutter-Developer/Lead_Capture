import 'api_config.dart';

/// upload.php returns an attachment `id`; leads/deals/tasks/… link files to a
/// record by sending `attachment_ids` on create/update, and remove them with
/// `delete_attachment` (by id). The app only keeps file URLs in its models,
/// so this registry remembers url -> id for files uploaded in this session
/// and for attachments read back from the API.
class ApiAttachments {
  ApiAttachments._();
  static final Map<String, int> _ids = {};

  static String _key(String url) => ApiConfig.toRelativePath(url);

  static void register(String url, int? id) {
    if (id != null && url.isNotEmpty) _ids[_key(url)] = id;
  }

  static int? idOf(String url) => _ids[_key(url)];

  /// Ids for the urls we know about (new uploads + loaded attachments).
  static List<int> idsFor(Iterable<String> urls) =>
      [for (final u in urls) if (idOf(u) != null) idOf(u)!];
}
