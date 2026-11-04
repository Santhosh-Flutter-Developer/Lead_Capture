import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class FeedService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _feedCollection(String cid) {
    return firebase.users.doc(cid).collection(Collections.feed.name);
  }

  static Future<void> _addFeedHistory({
    required String cid,
    required String feedId,
    required FeedHistoryModel history,
  }) async {
    await _feedCollection(
      cid,
    ).doc(feedId).collection('history').add(history.toMap());
  }

  static Future<void> createFeed({required FeedModel feed}) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) {
        throw "Missing cid or uid";
      }

      final userDoc = firebase.users.doc(cid);
      final feedRef = userDoc.collection(Collections.feed.name);

      var lastFeed = await feedRef.orderBy('feedNumber').limit(1).get();
      var newFeedNumber = 0;
      if (lastFeed.docs.isNotEmpty) {
        var lastFeedNumber = lastFeed.docs.first.data()['feedNumber'];
        if (lastFeedNumber != null) {
          newFeedNumber = lastFeedNumber + 1;
        }
      } else {
        newFeedNumber = 1;
      }

      var map = feed.toMap();
      map['feedNumber'] = newFeedNumber;

      final feedDoc = await feedRef.add(map);

      await _addFeedHistory(
        cid: cid,
        feedId: feedDoc.id,
        history: FeedHistoryModel(
          userId: uid,
          action: 'Created',
          content: feed.content,
          timestamp: feed.createdAt,
        ),
      );

      // List<String> workflows = feed.workflow;
      // List<String> fcmIds = [];
      // List<String> toUids = [];
      // for (var i in workflows) {
      //   var userFcmIds = await AuthService.getUserFcmIds(uid: i);
      //   if (userFcmIds.isNotEmpty) {
      //     fcmIds.addAll(userFcmIds);
      //     toUids.add(i);
      //   }
      // }

      // var user = await Spdb.getUser();
      // PostNotificationService.sendNotification(
      //   model: NotificationModel(
      //     title: 'New Feed : ${feed.feedName}',
      //     message: 'New feed has created by ${user?.name}',
      //     toFcms: fcmIds,
      //     toUids: workflows,
      //     payload: {},
      //   ),
      // );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error creating feed: $e\n$st");
      rethrow;
    }
  }

  static Future<FeedModel> getFeed({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var feedDoc = await firebase.users
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(uid)
          .get();

      if (feedDoc.exists) {
        var feedData = feedDoc.data();
        if (feedData != null) {
          var feed = FeedModel.fromMap(feedDoc.id, feedData);
          return feed;
        } else {
          throw 'Feed data is empty';
        }
      } else {
        throw 'Feed not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating feed: $e';
    }
  }

  static Future<List<FeedModel>> getAllFeeds() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.feed.name)
          .orderBy('createdAt', descending: true)
          .get();

      List<FeedModel> feed = querySnapshot.docs.map((doc) {
        return FeedModel.fromMap(doc.id, doc.data());
      }).toList();

      return feed;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching feed: $e';
    }
  }

  static Future<void> updateCommentReaction({
    required String feedId,
    required String commentId,
    required Map<String, List<String>> reactions,
  }) async {
    try {
      final cid = await Spdb.getCid();

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) throw "Feed post does not exist!";

      final data = snapshot.data() as Map<String, dynamic>;
      List<dynamic> comments = data['comments'] ?? [];

      // Update the reactions of the specific comment
      comments = comments.map((c) {
        if (c['commentId'] == commentId) {
          final updatedComment = Map<String, dynamic>.from(c);
          updatedComment['reactions'] = reactions;
          return updatedComment;
        }
        return c;
      }).toList();

      await docRef.update({'comments': comments});
    } catch (e) {
      debugPrint("Error updating comment reaction: $e");
      throw "Error updating comment reaction: $e";
    }
  }

  static Future<void> toggleReaction({
    required String feedId,
    required String userId,
    required String type,
  }) async {
    var cid = await Spdb.getCid();

    final docRef = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.feed.name)
        .doc(feedId);

    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw "Feed post does not exist!";
    }

    final data = snapshot.data() as Map<String, dynamic>;

    // Get existing reactions
    List<dynamic> rawReactions = data['reactions'] ?? [];
    List<Map<String, dynamic>> reactions = List<Map<String, dynamic>>.from(
      rawReactions,
    );

    // Check if user already reacted
    final index = reactions.indexWhere((r) => r['userId'] == userId);

    if (index != -1) {
      // Remove reaction (toggle off)
      reactions.removeAt(index);
    } else {
      // Add reaction (toggle on)
      reactions.add({
        'userId': userId,
        'type': type,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Update Firestore
    await docRef.update({'reactions': reactions});
  }

  static Future<void> toggleSaveFeed({
    required String feedId,
    required String userId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);

      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw "Feed post does not exist!";
      }

      final data = snapshot.data() as Map<String, dynamic>;
      List<dynamic> rawSavedBy = data['savedBy'] ?? [];
      List<String> savedBy = List<String>.from(rawSavedBy);

      if (savedBy.contains(userId)) {
        // Remove from savedBy
        await docRef.update({
          'savedBy': FieldValue.arrayRemove([userId])
        });
      } else {
        // Add to savedBy
        await docRef.update({
          'savedBy': FieldValue.arrayUnion([userId])
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error toggling save feed: $e\n$st");
      throw "Error toggling save feed: $e";
    }
  }

  static Future<void> addComment({
    required String feedId,
    required CommentModel comment,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);
      await docRef.update({
        'comments': FieldValue.arrayUnion([comment.toMap()]),
        'commentsCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw 'Error adding comment: $e';
    }
  }

  static Future<void> editComment({
    required String feedId,
    required String commentId,
    required String content,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final currentUid = await Spdb.getUid();

      if (cid == null || currentUid == null) {
        throw 'Missing cid or uid';
      }

      final updatedContent = content.trim();
      if (updatedContent.isEmpty) {
        throw 'Comment content cannot be empty';
      }

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw 'Feed not found';
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      final index = comments.indexWhere((c) => c['commentId'] == commentId);
      if (index == -1) {
        throw 'Comment not found';
      }

      final authorId = comments[index]['authorId']?.toString() ?? '';
      if (authorId != currentUid) {
        throw 'Only comment creator can edit this comment';
      }

      comments[index] = {...comments[index], 'content': updatedContent};

      await docRef.update({'comments': comments});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error editing comment: $e';
    }
  }

  static Future<void> deleteComment({
    required String feedId,
    required String commentId,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final currentUid = await Spdb.getUid();

      if (cid == null || currentUid == null) {
        throw 'Missing cid or uid';
      }

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw 'Feed not found';
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      final index = comments.indexWhere((c) => c['commentId'] == commentId);
      if (index == -1) {
        throw 'Comment not found';
      }

      final authorId = comments[index]['authorId']?.toString() ?? '';
      if (authorId != currentUid) {
        throw 'Only comment creator can delete this comment';
      }

      comments.removeAt(index);

      await docRef.update({
        'comments': comments,
        'commentsCount': FieldValue.increment(-1),
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error deleting comment: $e';
    }
  }

  static Future<void> editFeed({
    required String uid,
    required FeedModel feed,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var currentUid = await Spdb.getUid();

      if (cid == null || currentUid == null) {
        throw 'Missing cid or uid';
      }

      final feedDoc = await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(uid)
          .get();

      if (!feedDoc.exists) {
        throw 'Feed not found';
      }

      final feedData = feedDoc.data();
      final authorId = feedData?['authorId']?.toString() ?? '';

      if (authorId != currentUid) {
        throw 'Only post creator can edit this post';
      }

      final updatedAt = DateTime.now();
      final existingFeed = FeedModel.fromMap(uid, feedData ?? {});
      final feedToSave = feed.copyWith(
        updatedAt: updatedAt,
        comments: existingFeed.comments,
        commentsCount: existingFeed.commentsCount,
      );

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.feed.name}',
        uid,
        feedToSave.toUpdateMap(),
        activity: '${feed.content} has been updated',
      );

      await _addFeedHistory(
        cid: cid,
        feedId: uid,
        history: FeedHistoryModel(
          userId: currentUid,
          action: 'Edited',
          content: feed.content,
          timestamp: updatedAt,
        ),
      );

      // List<String> workflows = feed.workflow;
      // List<String> fcmIds = [];
      // List<String> toUids = [];
      // for (var i in workflows) {
      //   var userFcmIds = await AuthService.getUserFcmIds(uid: i);
      //   if (userFcmIds.isNotEmpty) {
      //     fcmIds.addAll(userFcmIds);
      //     toUids.add(i);
      //   }
      // }

      // var user = await Spdb.getUser();
      // PostNotificationService.sendNotification(
      //   model: NotificationModel(
      //     title: 'Feed Modified : ${feed.feedName}',
      //     message: 'Feed has modified created by ${user?.name}',
      //     toFcms: fcmIds,
      //     toUids: workflows,
      //     payload: {},
      //   ),
      // );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating feed: $e';
    }
  }

  static Future<void> deleteFeed({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final currentUid = await Spdb.getUid();

      if (cid == null || currentUid == null) {
        throw 'Missing cid or uid';
      }

      final feedDocRef = _feedCollection(cid).doc(uid);
      final feedDoc = await feedDocRef.get();

      if (!feedDoc.exists) {
        throw 'Feed not found';
      }

      final feedData = feedDoc.data() ?? {};
      final authorId = feedData['authorId']?.toString() ?? '';
      if (authorId != currentUid) {
        throw 'Only post creator can delete this post';
      }

      final feed = FeedModel.fromMap(feedDoc.id, feedData);

      // Best-effort cleanup of uploaded assets before deleting the post.
      final urls = <String>{
        ...feed.mediaImages.map((file) => file.url),
        ...feed.attachments.map((file) => file.url),
      };

      for (final url in urls) {
        if (url.trim().isEmpty) continue;
        try {
          await StorageService.deleteImage(url);
        } catch (_) {
          // Ignore media cleanup failures and continue deleting the post.
        }
      }

      // Firestore does not auto-delete subcollections when parent doc is deleted.
      while (true) {
        final historySnap = await feedDocRef
            .collection('history')
            .limit(100)
            .get();
        if (historySnap.docs.isEmpty) {
          break;
        }

        final batch = firestore.batch();
        for (final doc in historySnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await feedDocRef.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error deleting feed: $e';
    }
  }

  static Future<void> votePoll({
    required String feedId,
    required String optionId,
  }) async {
    try {
      String cid = await Spdb.getCid() ?? '';
      String uid = await Spdb.getUid() ?? '';

      if (uid.isEmpty) {
        throw 'User not found';
      }

      final docRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.feed.name)
          .doc(feedId);

      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data()!;
      FeedModel feed = FeedModel.fromMap(snap.id, data);

      if (feed.poll == null) return;

      if (feed.poll!.votedUserIds.contains(uid)) {
        throw 'You have already participated in this poll';
      }

      // Increase vote
      var hasOption = false;
      for (var option in feed.poll!.options) {
        if (option.optionId == optionId) {
          option.votes += 1;
          hasOption = true;
          break;
        }
      }

      if (!hasOption) {
        throw 'Invalid poll option selected';
      }

      final updatedPoll = PollModel(
        pollId: feed.poll!.pollId,
        question: feed.poll!.question,
        options: feed.poll!.options,
        votedUserIds: [...feed.poll!.votedUserIds, uid],
      );

      // Upload back
      await docRef.update({"poll": updatedPoll.toMap()});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating feed: $e';
    }
  }
}
