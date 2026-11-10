import '/models/models.dart';
import 'api_config.dart';
import 'api_mappers.dart';

/// feed.php rows -> FeedModel / CommentModel.
class FeedMappers {
  FeedMappers._();

  static String _avatar(dynamic v) {
    final s = Js.s(v);
    if (s.isEmpty || s.startsWith('assets/')) return '';
    return ApiConfig.resolveFileUrl(s);
  }

  static FileModel _file(Map<String, dynamic> m) {
    final url = ApiConfig.resolveFileUrl(Js.s(m['url']));
    final name = Js.s(m['name']);
    final dot = name.lastIndexOf('.');
    return FileModel(
      name: name,
      url: url,
      size: 0,
      extension: dot >= 0 ? name.substring(dot + 1) : '',
      mimeType: '',
      createdAt: null,
    );
  }

  static CommentModel comment(Map<String, dynamic> m) => CommentModel(
        commentId: Js.s(m['id']),
        authorId: Js.s(m['user_uid']),
        authorName: Js.s(m['user_name']),
        authorAvatar: _avatar(m['user_photo']),
        content: Js.s(m['comment']),
        createdAt: Js.dt(m['created_at']) ?? DateTime.now(),
      );

  static PollModel? _poll(dynamic v) {
    if (v is! Map) return null;
    final m = Js.m(v);
    return PollModel(
      pollId: Js.s(m['poll_id']),
      question: Js.s(m['question']),
      options: Js.mapList(m['options'])
          .map((o) => PollOption(
                optionId: Js.s(o['option_id']),
                title: Js.s(o['title']),
                votes: Js.i(o['votes']) ?? 0,
              ))
          .toList(),
      votedUserIds: (m['voted_user_ids'] is List)
          ? (m['voted_user_ids'] as List).map((e) => e.toString()).toList()
          : <String>[],
    );
  }

  static FeedModel feed(Map<String, dynamic> m) {
    final likes = (m['likes_list'] is List)
        ? (m['likes_list'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final saved = (m['saved_list'] is List)
        ? (m['saved_list'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final comments = Js.mapList(m['comments']).map(comment).toList();
    return FeedModel(
      uid: Js.s(m['uid']),
      authorId: Js.s(m['created_by']),
      authorName: Js.s(m['created_by_name']),
      authorAvatar: _avatar(m['created_by_photo']),
      content: Js.s(m['content']),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
      mediaImages: Js.mapList(m['media_images']).map(_file).toList(),
      attachments: Js.mapList(m['file_attachments']).map(_file).toList(),
      taggedUsers: const [],
      reactions: likes.map((u) => ReactionModel(userId: u, type: 'like')).toList(),
      savedBy: saved,
      poll: _poll(m['poll_data']),
      commentsCount: Js.i(m['comment_count']) ?? comments.length,
      comments: comments,
    );
  }
}
