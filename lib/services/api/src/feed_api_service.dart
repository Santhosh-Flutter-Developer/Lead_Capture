import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// feed.php (actions per the PHP source): list, create, edit, like,
/// toggle_save, vote_poll, comments, add_comment, delete_comment, delete.
/// Attachments are uploaded first through upload.php (module `feed`); the
/// returned URLs are sent in `media_images` / `attachments`.
class FeedApiService {
  FeedApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.feed, action: action, body: body ?? {});

  static Future<ApiResponse> list({int page = 1}) => call('list', {'page': page});
  static Future<ApiResponse> comments(String feedUid) => call('comments', {'feed_uid': feedUid});
  static Future<ApiResponse> addComment({
    required String feedUid,
    required String comment,
    String? replyToCommentId,
  }) =>
      call('add_comment', {
        'feed_uid': feedUid,
        'comment': comment,
        if (replyToCommentId != null && replyToCommentId.isNotEmpty)
          'reply_to_comment_id': int.tryParse(replyToCommentId) ?? replyToCommentId,
      });
  static Future<ApiResponse> editComment({required int commentId, required String comment}) =>
      call('edit_comment', {'comment_id': commentId, 'comment': comment});
  static Future<ApiResponse> toggleCommentReaction({required int commentId, required String emoji}) =>
      call('toggle_comment_reaction', {'comment_id': commentId, 'emoji': emoji});
  static Future<ApiResponse> deleteComment(int commentId) =>
      call('delete_comment', {'comment_id': commentId});
  static Future<ApiResponse> like(String uid) => call('like', {'uid': uid});
  static Future<ApiResponse> toggleSave(String uid) => call('toggle_save', {'uid': uid});
  static Future<ApiResponse> votePoll({required String uid, required String optionId}) =>
      call('vote_poll', {'uid': uid, 'option_id': optionId});
  static Future<ApiResponse> delete(String uid) => call('delete', {'uid': uid});
}