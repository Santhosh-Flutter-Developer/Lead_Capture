import 'package:flutter/material.dart';
import '/services/api/api.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Feed via feed.php. Server enforces ownership (creator/admin), writes the
/// activity log and keeps likes/saves/poll votes. Posts are polled; every
/// mutation calls ApiLive.changed({'feed'}).
class FeedService {
  static Never _unsupported(String what) =>
      throw '$what is not supported by the server API.';

  /// All posts (feed.php `list` is paged by 50).
  static Future<List<FeedModel>> getAllFeeds() async {
    try {
      final out = <FeedModel>[];
      for (var page = 1; page <= 20; page++) {
        final res = (await FeedApiService.list(page: page)).ensureSuccess();
        final rows = Js.mapList(res.data);
        out.addAll(rows.map(FeedMappers.feed));
        if (rows.length < 50) break;
      }
      return out;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw 'Error fetching feed: ${_msg(e)}';
    }
  }

  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  /// Live list: refetched every 30 s and after any feed mutation.
  static Stream<List<FeedModel>> watchFeeds() =>
      ApiLive.watch<List<FeedModel>>({'feed'}, getAllFeeds);

  static Future<FeedModel> getFeed({required String uid}) async {
    for (var page = 1; page <= 20; page++) {
      final res = (await FeedApiService.list(page: page)).ensureSuccess();
      final rows = Js.mapList(res.data);
      for (final r in rows) {
        if (Js.s(r['uid']) == uid) return FeedMappers.feed(r);
      }
      if (rows.length < 50) break;
    }
    throw 'Feed not found';
  }

  static List<String> _urls(List<FileModel> l) =>
      l.map((f) => f.url).where((u) => u.trim().isNotEmpty).toList();

  static Map<String, dynamic>? _pollBody(PollModel? p) => p == null
      ? null
      : {
          'poll_id': p.pollId,
          'question': p.question,
          'options': p.options.map((o) => {'title': o.title, 'votes': o.votes}).toList(),
          'voted_user_ids': p.votedUserIds,
        };

  static Future<void> createFeed({required FeedModel feed}) async {
    try {
      final poll = feed.poll;
      (await FeedApiService.call('create', {
        'content': feed.content,
        'media_images': _urls(feed.mediaImages),
        'attachments': _urls(feed.attachments),
        if (poll != null && poll.question.trim().isNotEmpty)
          'poll': {
            'question': poll.question,
            'options': poll.options.map((o) => o.title).toList(),
          },
      }))
          .ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error creating feed: $e\n$st");
      throw 'Error creating feed: ${_msg(e)}';
    }
  }

  static Future<void> editFeed({
    required String uid,
    required FeedModel feed,
  }) async {
    try {
      (await FeedApiService.call('edit', {
        'uid': uid,
        'content': feed.content,
        'media_images': _urls(feed.mediaImages),
        'attachments': _urls(feed.attachments),
        'poll': _pollBody(feed.poll),
      }))
          .ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw 'Error updating feed: ${_msg(e)}';
    }
  }

  static Future<void> deleteFeed({required String uid}) async {
    try {
      (await FeedApiService.delete(uid)).ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting feed: ${_msg(e)}';
    }
  }

  /// feed.php `like` toggles the current user's like ([userId]/[type] unused).
  static Future<void> toggleReaction({
    required String feedId,
    required String userId,
    required String type,
  }) async {
    (await FeedApiService.like(feedId)).ensureSuccess();
  }

  static Future<void> toggleSaveFeed({
    required String feedId,
    required String userId,
  }) async {
    try {
      (await FeedApiService.toggleSave(feedId)).ensureSuccess();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw "Error toggling save feed: ${_msg(e)}";
    }
  }

  static Future<void> votePoll({
    required String feedId,
    required String optionId,
  }) async {
    try {
      (await FeedApiService.votePoll(uid: feedId, optionId: optionId)).ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw _msg(e);
    }
  }

  /// Adds a comment and returns the saved one (with its server id), or null
  /// when it could not be located afterwards.
  static Future<CommentModel?> addComment({
    required String feedId,
    required CommentModel comment,
  }) async {
    try {
      (await FeedApiService.addComment(
        feedUid: feedId,
        comment: comment.content,
        replyToCommentId: comment.replyToCommentId,
      ))
          .ensureSuccess();
      ApiLive.changed({'feed'});
      final res = (await FeedApiService.comments(feedId)).ensureSuccess();
      final list = Js.mapList(res.data).map(FeedMappers.comment).toList();
      if (list.isEmpty) return null;
      return list.last;
    } catch (e) {
      throw 'Error adding comment: ${_msg(e)}';
    }
  }

  static Future<List<CommentModel>> getComments({required String feedId}) async {
    final res = (await FeedApiService.comments(feedId)).ensureSuccess();
    return Js.mapList(res.data).map(FeedMappers.comment).toList();
  }

  static Future<void> deleteComment({
    required String feedId,
    required String commentId,
  }) async {
    try {
      final id = int.tryParse(commentId);
      if (id == null) throw 'Comment is not saved yet, refresh and try again.';
      (await FeedApiService.deleteComment(id)).ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e) {
      throw 'Error deleting comment: ${_msg(e)}';
    }
  }

  static Future<void> editComment({
    required String feedId,
    required String commentId,
    required String content,
  }) async {
    try {
      final id = int.tryParse(commentId);
      if (id == null) throw 'Comment is not saved yet, refresh and try again.';
      (await FeedApiService.editComment(commentId: id, comment: content)).ensureSuccess();
      ApiLive.changed({'feed'});
    } catch (e) {
      throw 'Error editing comment: ${_msg(e)}';
    }
  }

  /// The server toggles [emoji] for the current user; [reactions] is the
  /// optimistic state already applied in the UI and is not sent.
  static Future<void> updateCommentReaction({
    required String feedId,
    required String commentId,
    required Map<String, List<String>> reactions,
    String emoji = '❤️',
  }) async {
    try {
      final id = int.tryParse(commentId);
      if (id == null) throw 'Comment is not saved yet, refresh and try again.';
      (await FeedApiService.toggleCommentReaction(commentId: id, emoji: emoji)).ensureSuccess();
    } catch (e) {
      throw 'Error updating reaction: ${_msg(e)}';
    }
  }
}