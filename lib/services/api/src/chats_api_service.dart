import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// chats.php – REST only. There is no documented realtime/WebSocket channel,
/// so callers poll `threads` / `messages` (see ChatService).
class ChatsApiService {
  ChatsApiService._();
  static final _c = ApiClient.instance;

  /// Generic POST (body fields exactly as chats.php reads them).
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      _c.post(ApiEndpoints.chats, action: action, body: body ?? {});

  static Future<ApiResponse> threads() => _c.get(ApiEndpoints.chats, action: 'threads');
  static Future<ApiResponse> groupMembers(String chatUid) =>
      _c.get(ApiEndpoints.chats, action: 'group_members', query: {'chat_uid': chatUid});
  /// Also marks the other users' unread messages as read for the caller.
  static Future<ApiResponse> messages(String chatUid) =>
      _c.get(ApiEndpoints.chats, action: 'messages', query: {'chat_uid': chatUid});
  static Future<ApiResponse> chatAttachments(String chatUid) =>
      _c.get(ApiEndpoints.chats, action: 'chat_attachments', query: {'chat_uid': chatUid});

  /// Sends text and/or attachments (multipart when [files] is non-empty).
  static Future<ApiResponse> sendMessage({
    required String chatUid,
    String? message,
    int? replyToId,
    String? replyToSnippet,
    List<ApiUploadFile> files = const [],
  }) {
    final fields = {
      'chat_uid': chatUid,
      if (message != null) 'message': message,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToSnippet != null) 'reply_to_snippet': replyToSnippet,
    };
    if (files.isEmpty) return _c.post(ApiEndpoints.chats, action: 'send_message', body: fields);
    return _c.multipart(
      ApiEndpoints.chats,
      action: 'send_message',
      fields: fields,
      files: files
          .map((f) => ApiUploadFile(field: 'attachments[]', fileName: f.fileName, bytes: f.bytes))
          .toList(),
    );
  }
}
