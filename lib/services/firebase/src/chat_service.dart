import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
// import 'package:mime/mime.dart';
// import 'package:path/path.dart' as path;
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class ChatService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static final ValueNotifier<int> _unviewedCount = ValueNotifier<int>(0);

  static Stream<List<MessagesModel>> getChatMessagesStream({
    required String uid,
    int? limit,
  }) async* {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();
    var query = firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(uid)
        .collection(Collections.messages.name)
        .orderBy('timestamp', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    yield* query.snapshots().map((snapshot) {
      final messages = snapshot.docs
          .map((doc) {
            try {
              var data = doc.data();
              data['uid'] = doc.id;

              final message = MessagesModel.fromMap(doc.id, data);

              if (userid != null && message.deletedFor.contains(userid)) {
                debugPrint('Message ${doc.id} filtered out for user $userid (deletedFor)');
                return null;
              }

              return message;
            } catch (e, st) {
              debugPrint('Error parsing message ${doc.id}: $e');
              debugPrint('Stack trace: $st');
              return null;
            }
          })
          .whereType<MessagesModel>()
          .toList();
      
      debugPrint('Loaded ${messages.length} messages for chat $uid (source: ${snapshot.metadata.hasPendingWrites ? "local" : "server"})');
      return messages;
    });
  }

  static Future<List<MessagesModel>> getChatMessagesPage({
    required String uid,
    required int limit,
    required DateTime lastTimestamp,
  }) async {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();

    final snapshot = await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(uid)
        .collection(Collections.messages.name)
        .orderBy('timestamp', descending: true)
        .startAfter([lastTimestamp.millisecondsSinceEpoch])
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;

          final message = MessagesModel.fromMap(doc.id, data);

          if (userid != null && message.deletedFor.contains(userid)) {
            return null;
          }

          return message;
        })
        .whereType<MessagesModel>()
        .toList();
  }

  static Stream<List<MessagesModel>> getThreadMessagesStream({
    required String chatId,
    required String parentMessageId,
  }) async* {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();
    yield* firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .where('threadId', isEqualTo: parentMessageId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                var data = doc.data();
                data['uid'] = doc.id;

                final message = MessagesModel.fromMap(doc.id, data);

                if (userid != null && message.deletedFor.contains(userid)) {
                  return null;
                }

                return message;
              })
              .whereType<MessagesModel>()
              .toList();
        });
  }

  static Future<List<MessagesModel>> getChatMessages({
    required String uid,
  }) async {
    var cid = await Spdb.getCid();
    var userid = await Spdb.getUid();

    final snapshot = await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(uid)
        .collection(Collections.messages.name)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;

          final message = MessagesModel.fromMap(doc.id, data);

          if (userid != null && message.deletedFor.contains(userid)) {
            return null;
          }

          return message;
        })
        .whereType<MessagesModel>()
        .toList();
  }

  static Future<List<MessagesModel>> searchMessages({
    required String chatId,
    required String searchTerm,
  }) async {
    final messages = await getChatMessages(uid: chatId);
    final terms = searchTerm
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (terms.isEmpty) return [];

    return messages.where((msg) {
      final text = msg.message.toLowerCase();

      // Check if all search terms are contained in either the message text or attachment names
      final matchText = terms.every((term) => text.contains(term));
      final matchFiles = msg.attachments.any((file) {
        final name = file.name.toLowerCase();
        return terms.every((term) => name.contains(term));
      });

      return matchText || matchFiles;
    }).toList();
  }

  static Future<void> updateSeenChat({
    required String chatId,
    required String messageId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$chatId/${Collections.messages.name}',
        messageId,
        {
          'seenBy': FieldValue.arrayUnion([uid]),
        },
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw "Error updating seen status: $e";
    }
  }

  static final Set<String> _seenRunning = {};
  static final Set<String> _seenRerun = {};

  // ── "Seen" is only recorded while the user is really looking at the app ──
  //
  // A chat that is merely OPEN in a background browser tab / minimized window
  // / backgrounded phone app used to mark every incoming message as seen
  // immediately, so "Viewed by ..." listed people who never saw the message.
  // Now seen-marking is paused while the app is not in the foreground and
  // the open chat is marked as soon as the user comes back.
  static final _SeenLifecycleObserver _seenObserver = _SeenLifecycleObserver();
  static bool _seenObserverAttached = false;

  static void _attachSeenObserver() {
    if (_seenObserverAttached) return;
    _seenObserverAttached = true;
    WidgetsBinding.instance.addObserver(_seenObserver);
  }

  /// `null` lifecycle (very early start-up) counts as foreground.
  static bool get _isAppForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Called when the app returns to the foreground: mark the chat that is
  /// open on screen (and only that one) as seen now.
  static void _onAppResumed() {
    final active = _activeChatId;
    if (active != null) markChatMessagesAsSeen(active);
  }

  /// Marks EVERY unseen message of [chatId] as seen by the current user.
  ///
  /// Queries Firestore directly (not the UI list), so messages that are not
  /// rendered (deleted-for-me, missing timestamp, etc.) are still cleared and
  /// one failing update can no longer stop the rest. Uses batched writes.
  static Future<void> markChatMessagesAsSeen(String chatId) async {
    if (chatId.isEmpty) return;
    _attachSeenObserver();
    // Not looking at the app (background tab, minimized, phone locked):
    // do NOT mark anything as seen. _onAppResumed() will do it later.
    if (!_isAppForeground) return;
    if (_seenRunning.contains(chatId)) {
      _seenRerun.add(chatId); // new messages arrived mid-run -> run again
      return;
    }
    _seenRunning.add(chatId);
    try {
      do {
        _seenRerun.remove(chatId);
        final cid = await Spdb.getCid();
        final uid = await Spdb.getUid();
        if (cid == null || uid == null) return;

        final snap = await FirebaseFirestore.instance
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.chats.name)
            .doc(chatId)
            .collection(Collections.messages.name)
            .where('receiverId', arrayContains: uid)
            .get();

        final unseen = snap.docs.where((d) {
          final seenBy = List.from(d.data()['seenBy'] ?? []);
          return !seenBy.contains(uid);
        }).toList();

        for (var i = 0; i < unseen.length; i += 400) {
          // App went to the background while we were fetching: stop.
          if (!_isAppForeground) return;
          final batch = FirebaseFirestore.instance.batch();
          for (final d in unseen.skip(i).take(400)) {
            batch.update(d.reference, {
              'seenBy': FieldValue.arrayUnion([uid]),
            });
          }
          await batch.commit();
        }
      } while (_seenRerun.contains(chatId));
    } catch (e, st) {
      debugPrint('markChatMessagesAsSeen failed: $e\n$st');
      await ErrorService.recordError(e, st);
    } finally {
      _seenRunning.remove(chatId);
    }
  }

  static Future<void> updateTypingOnChat({
    required String chatId,
    required bool status,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      var mapDoc = {
        'typing': {'status': status, 'userId': uid},
      };

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatId,
        mapDoc,
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw "Error updating seen status: $e";
    }
  }

  static Future<MessagesModel> getChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .collection(Collections.messages.name)
          .doc(messageId)
          .get(const GetOptions(source: Source.serverAndCache));
      var data = doc.data();
      data!['uid'] = doc.id;
      return MessagesModel.fromMap(doc.id, data);
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<MessagesModel?> deleteChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final cid = await Spdb.getCid();

      final chatRef = firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId);

      final messageRef =
          chatRef.collection(Collections.messages.name).doc(messageId);

      final doc = await messageRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (!doc.exists) return null;

      final message = MessagesModel.fromMap(doc.id, doc.data()!);

      // Read participants so the message is hidden for everyone
      final chatDoc = await chatRef.get();
      final chatData = chatDoc.data();
      final participants = List<String>.from(
        chatData?['participants'] ?? <String>[],
      );

      // ✅ STEP 1: delete for everyone (sender + all receivers)
      final everyone = <String>{
        ...participants,
        ...message.receiverId,
        message.senderId,
      }.where((e) => e.isNotEmpty).toList();

      await messageRef.update({
        "deletedFor": FieldValue.arrayUnion(everyone),
      });

      // ✅ STEP 2: if this was the LAST MESSAGE, move lastMessage back
      final lastMessage = chatData?['lastMessage'];

      if (lastMessage != null && lastMessage['messageId'] == messageId) {
        final messagesSnapshot = await chatRef
            .collection(Collections.messages.name)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        MessagesModel? newLast;

        for (var d in messagesSnapshot.docs) {
          final msg = MessagesModel.fromMap(d.id, d.data());

          // skip deleted messages and thread replies
          if (msg.deletedFor.isEmpty && msg.threadId == null) {
            newLast = msg;
            break;
          }
        }

        // ✅ STEP 3: update lastMessage
        await chatRef.update({
          "lastMessage": newLast != null
              ? LastMessageModel(
                  messageId: newLast.uid,
                  message: newLast.message,
                  senderId: newLast.senderId,
                  timestamp: newLast.timestamp,
                ).toMap()
              : null,
        });
      }

      return message;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> editChatMessage({
    required String uid,
    required String message,
    required String chatId,
    List<FileModel>? attachments,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var userId = await Spdb.getUid();

      List<String> receivers = [];
      var chatDoc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(uid)
          .get();

      if (chatDoc.exists) {
        var participants = chatDoc.data()?['participants'];
        if (participants != null) {
          receivers = List<String>.from(participants);
          receivers.remove(userId);
        }
      }

      MessagesModel chat = MessagesModel(
        chatId: chatId,
        senderId: userId ?? '',
        receiverId: receivers,
        message: message,
        attachments: attachments ?? [],
        edited: true,
        editHistory: [MessagesEditHistory(message: message)],
      );

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$uid/${Collections.messages.name}',
        chatId,
        chat.toEditMap(),
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<void> sendChatMessage({
    required String chatId,
    required String message,
    List<FileModel>? attachments,
    String? replyFor,
    List<MentionModel>? mentions,
    String? threadId,
    // Pre-generated message id, so the UI can show the message instantly and
    // swap it for the real one without a duplicate.
    String? messageId,
    // Original send time (the moment the user tapped send, not upload end).
    DateTime? timestamp,
    // When already known by the caller we skip an extra Firestore read.
    List<String>? participants,
    // Set when this message is a FORWARD of another message.
    String? forwardFrom,
    String? forwardFromMessageId,
    String? forwardFromChatId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var senderId = await Spdb.getUid();

      List<String> receivers = [];
      if (participants != null && participants.isNotEmpty) {
        receivers = List<String>.from(participants);
        receivers.remove(senderId);
      } else {
        var chatDoc = await firebase.users
            .doc(cid)
            .collection(Collections.chats.name)
            .doc(chatId)
            .get();

        if (chatDoc.exists) {
          receivers = List<String>.from(chatDoc.data()?['participants'] ?? []);
          receivers.remove(senderId);
        }
      }

      final files = attachments ?? [];

      String lastMsg = message;

      if (files.isNotEmpty && message.trim().isEmpty) {
        final mime = files.first.mimeType;

        if (mime.startsWith('image')) {
          lastMsg = "📷 Photo";
        } else if (mime.startsWith('video')) {
          lastMsg = "🎥 Video";
        } else if (mime.startsWith('audio')) {
          lastMsg = files.first.isVoice ? "🎤 Voice message" : "🎵 Audio";
        } else {
          lastMsg = "📄 Document";
        }
      }

      MessagesModel chat = MessagesModel(
        chatId: chatId,
        senderId: senderId!,
        receiverId: receivers,
        message: message,
        replyFor: replyFor,
        attachments: attachments ?? [],
        mentions: mentions ?? [],
        threadId: threadId,
        timestamp: timestamp,
        forwardFrom: forwardFrom,
        forwardFromMessageId: forwardFromMessageId,
        forwardFromChatId: forwardFromChatId,
      );

      final docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}/$chatId/${Collections.messages.name}',
        chat.toMap(),
        docId: messageId,
      );

      final updateData = <String, dynamic>{
        "deletedFor": [],
        "updatedAt": DateTime.now().millisecondsSinceEpoch,
      };

      if (threadId == null) {
        updateData["lastMessage"] = LastMessageModel(
          messageId: docRef.id,
          message: lastMsg,
          senderId: senderId,
          timestamp: DateTime.now(),
        ).toMap();
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatId,
        updateData,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw "Error sending chat message: $e";
    }
  }

  /// Total unread messages (sidebar "Chats" badge).
  static ValueListenable<int> unviewedCount() {
    _ensureUnviewedListener();
    return _unviewedCount;
  }

  /// Unread messages per chat id (chat list row badges).
  static ValueListenable<Map<String, int>> unviewedByChat() {
    _ensureUnviewedListener();
    return _unviewedByChat;
  }

  static final ValueNotifier<Map<String, int>> _unviewedByChat =
      ValueNotifier<Map<String, int>>(<String, int>{});
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unviewedSub;
  static String? _unviewedKey;

  /// Starts ONE shared Firestore listener (per user) for all unread counts.
  /// Previously every call / every chat row opened its own listener, and a
  /// stalled or failed one left a stale badge on screen.
  static Future<void> _ensureUnviewedListener() async {
    final uid = await Spdb.getUid();
    final cid = await Spdb.getCid();
    if (uid == null || cid == null) return;

    final key = '$cid/$uid';
    if (_unviewedKey == key) return; // already listening for this user
    _unviewedKey = key;

    await _unviewedSub?.cancel();
    _publishUnviewed(<String, int>{}); // new user -> start clean

    _unviewedSub = FirebaseFirestore.instance
        .collectionGroup(Collections.messages.name)
        .where('receiverId', arrayContains: uid)
        .snapshots()
        .listen(
          (snapshot) {
            final counts = <String, int>{};
            for (final doc in snapshot.docs) {
              // users/<cid>/chats/<chatId>/messages/<messageId>
              final seg = doc.reference.path.split('/');
              if (seg.length < 6 ||
                  seg[0] != Collections.users.name ||
                  seg[1] != cid ||
                  seg[2] != Collections.chats.name) {
                continue;
              }
              final data = doc.data();
              final List seenBy = data['seenBy'] ?? [];
              final List deletedFor = data['deletedFor'] ?? [];
              if (!seenBy.contains(uid) &&
                  !deletedFor.contains(uid) &&
                  data['senderId'] != uid) {
                counts[seg[3]] = (counts[seg[3]] ?? 0) + 1;
              }
            }
            _publishUnviewed(counts);

            // A new message arrived for the chat that is open right now.
            final active = _activeChatId;
            if (active != null && (counts[active] ?? 0) > 0) {
              markChatMessagesAsSeen(active);
            }
          },
          onError: (Object e, StackTrace st) {
            debugPrint('Unread listener failed: $e');
            // Reset so the next access (or the retry below) re-attaches.
            _unviewedSub = null;
            _unviewedKey = null;
            Future.delayed(const Duration(seconds: 5), _ensureUnviewedListener);
          },
        );
  }

  /// Raw unread counts straight from Firestore (all chats).
  static Map<String, int> _rawUnviewed = <String, int>{};

  /// The chat that is open on screen right now. Its badge is always hidden;
  /// every other chat keeps its badge until that chat itself is opened.
  static String? _activeChatId;

  /// Marks [chatId] as the chat currently open on screen.
  ///
  /// Called from initState (i.e. during a build), so listeners are notified in
  /// a microtask: updating a ValueNotifier mid-build leaves the badge widgets
  /// stale until the next unrelated rebuild (the "hides only after I click
  /// something" bug).
  static void setActiveChat(String? chatId) {
    _activeChatId = (chatId == null || chatId.isEmpty) ? null : chatId;
    scheduleMicrotask(_republishUnviewed);
    // If it already has unread messages, clear them right away.
    if (_activeChatId != null && (_rawUnviewed[_activeChatId] ?? 0) > 0) {
      markChatMessagesAsSeen(_activeChatId!);
    }
  }

  static void clearActiveChat(String chatId) {
    if (_activeChatId == chatId) {
      _activeChatId = null;
      scheduleMicrotask(_republishUnviewed);
    }
  }

  static void _publishUnviewed(Map<String, int> counts) {
    _rawUnviewed = counts;
    _republishUnviewed();
  }

  /// Only notifies listeners when something really changed (no flicker).
  static void _republishUnviewed() {
    final visible = Map<String, int>.from(_rawUnviewed);
    if (_activeChatId != null) visible.remove(_activeChatId);
    if (!mapEquals(visible, _unviewedByChat.value)) {
      _unviewedByChat.value = visible;
    }
    final total = visible.values.fold<int>(0, (a, b) => a + b);
    if (total != _unviewedCount.value) _unviewedCount.value = total;
  }

  static Future<void> sendNotification({
    required String chatId,
    required String message,
    bool? isChat,
    String? messageId,
  }) async {
    try {
      var user = await Spdb.getUser();
      var name = user.name;
      var userId = user.uid;
      var chat = await _getChat(uid: chatId);

      List<String> toFcms = [];
      List<String> receivers = [];

      receivers.addAll(chat.participants);
      receivers.removeWhere((uid) => uid == userId);

      for (var receiverId in receivers) {
        var fcmIds = await AuthService.getUserFcmIds(uid: receiverId);
        toFcms.addAll(fcmIds);
      }

      NotificationModel notification = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: chat.isGroupChat ? (chat.title ?? 'Group Chat') : name,
        body: chat.isGroupChat ? '$name: $message' : message,
        toUids: receivers,
        toFcms: toFcms,
        senderId: await Spdb.getUid(),
        type: NotificationType.chat,
        payload: (isChat ?? false)
            ? {
                "type": "chat",
                "chatId": chat.uid,
                "chat": json.encode(chat.toMap()),
                "chatTitle": chat.isGroupChat
                    ? (chat.title ?? 'Group Chat')
                    : name,
                "senderName": name.toString(),
                "isGroupChat": chat.isGroupChat ? "true" : "false",
                "senderImageUrl": user.profilePic,
              }
            : {},
      );

      PostNotificationService.sendNotification(model: notification);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// Public, non-throwing chat lookup (used when opening a chat from a
  /// notification tap). Returns null if the chat can't be loaded.
  static Future<ChatModel?> getChat({required String uid}) async {
    try {
      return await _getChat(uid: uid);
    } catch (_) {
      return null;
    }
  }

  static Future<ChatModel> _getChat({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(uid)
          .get();
      return ChatModel.fromMap(doc.id, doc.data()!);
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<List<ChatModel>> getChatGroups() async {
    try {
      var cid = await Spdb.getCid();

      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .where('isGroupChat', isEqualTo: true)
          .get();

      List<ChatModel> result = [];

      for (var i in doc.docs) {
        result.add(ChatModel.fromMap(i.id, i.data()));
      }

      return result;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<String?> createGroupChat({required ChatModel model}) async {
    try {
      var cid = await Spdb.getCid();

      var doc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        model.toMap(),
        activity: '${model.title} has been added as a group chat',
      );

      sendNotification(
        chatId: doc.id,
        message: "Created group chat",
        isChat: true,
      );

      return doc.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<String> createIndividualChat({required String userId}) async {
    try {
      final cid = await Spdb.getCid();
      final currentUid = await Spdb.getUid();

      if (currentUid == null || currentUid.isEmpty || userId.isEmpty) {
        throw 'Something went wrong. Please try again later.';
      }

      final participantsKey = ([currentUid, userId]..sort()).join('_');

      final existingChatSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .where('participantsKey', isEqualTo: participantsKey)
          .where('isGroupChat', isEqualTo: false)
          .limit(1)
          .get();

      // If chat already exists → return it
      if (existingChatSnapshot.docs.isNotEmpty) {
        return existingChatSnapshot.docs.first.id;
      }

      // Create chat ONLY if not exists
      final chatModel = ChatModel(
        createdBy: currentUid,
        participants: [currentUid, userId],
        participantsKey: participantsKey,
        createdAt: DateTime.now(),
        lastMessage: null,
        isGroupChat: false,
        isPinned: false,
        isFavorite: false,
      );

      final chatDoc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.chats.name}',
        chatModel.toMap(),
      );

      debugPrint("the chat id on servuce id ${chatDoc.id}");

      await sendNotification(
        chatId: chatDoc.id,
        message: "Started chat",
        isChat: true,
      );

      return chatDoc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e\n$st");
      throw "Failed to create chat: $e";
    }
  }

  static Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    var cid = await Spdb.getCid();
    final ref = FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .doc(messageId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final reactions = Map<String, dynamic>.from(data["reactions"] ?? {});
    final List<dynamic> users = List.from(reactions[emoji] ?? []);
    if (users.contains(userId)) {
      users.remove(userId);
    } else {
      users.add(userId);
    }
    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }
    await ref.update({"reactions": reactions});
  }

  static Future<void> togglePin({
    required String chatId,
    required String messageId,
    required bool value,
  }) async {
    var cid = await Spdb.getCid();
    final ref = FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .collection(Collections.messages.name)
        .doc(messageId);

    await ref.update({'isPinned': value});
  }

  static Future<void> toggleChatPin({
    required String chatId,
    required bool value,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({'isPinnedBy.$uid': value, 'updatedAt': DateTime.now()});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> deleteChat({required String chatId}) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      final chatRef = FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId);

      final chatSnap = await chatRef.get();

      if (!chatSnap.exists) return;

      final data = chatSnap.data() as Map<String, dynamic>;

      final createdBy = data['createdBy'];
      final isGroupChat = data['isGroupChat'] ?? false;
      if (isGroupChat && createdBy != uid) {
        throw "Only group creator can delete this chat";
      }

      await chatRef.update({
        'deletedFor': FieldValue.arrayUnion([uid]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // await TrashService.moveToTrash(
      //   docRef: chatRef,
      //   docData: data,
      //   reason: 'chat_deleted',
      // );
      // final messagesRef = chatRef.collection(Collections.messages.name);

      // final messagesSnapshot = await messagesRef.get();
      // final batch = FirebaseFirestore.instance.batch();

      // for (final doc in messagesSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }

      // batch.delete(chatRef);

      // await batch.commit();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  static Future<void> restoreChat(ChatModel chat) async {
    var cid = await Spdb.getCid();

    if (chat.uid == null || chat.uid!.isEmpty) {
      throw Exception("Chat UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chat.uid)
        .set(chat.toMap());
  }

  static Future<void> toggleChatFavorite({
    required String chatId,
    required bool value,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({'isFavoriteBy.$uid': value, 'updatedAt': DateTime.now()});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  /// Short text used for notifications / chat-list preview of a message.
  static String _messagePreview(String message, List<FileModel> files) {
    if (message.trim().isNotEmpty) return message;
    if (files.isEmpty) return '';
    final f = files.first;
    if (f.mimeType.startsWith('image')) return '📷 Photo';
    if (f.mimeType.startsWith('video')) return '🎥 Video';
    if (f.mimeType.startsWith('audio')) {
      return f.isVoice ? '🎤 Voice message' : '🎵 Audio';
    }
    return '📄 Document';
  }

  /// Forwards [source] (text and/or any attachments: image, video, audio,
  /// voice note, documents) to every target and returns how many chats
  /// received it.
  ///
  ///  • [targetChatIds]: existing chats (groups or 1-to-1).
  ///  • [targetUserIds]: colleagues; their 1-to-1 chat is found or created.
  ///
  /// Attachments are re-used by URL (no re-upload). The forwarded copy keeps
  /// a pointer to the ORIGINAL author/message, even when a forwarded message
  /// is forwarded again. Reply link, mentions, reactions, pin and seen state
  /// are NOT copied.
  static Future<int> forwardMessage({
    required MessagesModel source,
    required String sourceChatId,
    List<String> targetChatIds = const [],
    List<String> targetUserIds = const [],
  }) async {
    final chatIds = <String>[...targetChatIds];

    for (final userId in targetUserIds) {
      try {
        String? id = await getChatUid(userId);
        id ??= await createIndividualChat(userId: userId);
        if (!chatIds.contains(id)) chatIds.add(id);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
      }
    }

    final originSender = source.forwardFrom ?? source.senderId;
    final originMessageId = source.forwardFromMessageId ?? source.uid;
    final originChatId = source.forwardFromChatId ?? sourceChatId;

    int delivered = 0;
    for (final chatId in chatIds) {
      try {
        await sendChatMessage(
          chatId: chatId,
          message: source.message,
          attachments: List<FileModel>.from(source.attachments),
          forwardFrom: originSender,
          forwardFromMessageId: originMessageId,
          forwardFromChatId: originChatId,
        );
        sendNotification(
          chatId: chatId,
          message: _messagePreview(source.message, source.attachments),
          isChat: true,
        );
        delivered++;
      } catch (e, st) {
        // One failing chat must not stop the others.
        await ErrorService.recordError(e, st);
      }
    }
    return delivered;
  }

  static Future<String?> getChatUid(String opponentUserId) async {
    var cid = await Spdb.getCid();
    var currentUserId = await Spdb.getUid();

    if (currentUserId == opponentUserId) return null;

    final key = ([currentUserId, opponentUserId]..sort()).join('_');

    var chat = await firebase.users
        .doc(cid)
        .collection(Collections.chats.name)
        .where('participantsKey', isEqualTo: key)
        .where('isGroupChat', isEqualTo: false)
        .limit(1)
        .get();

    if (chat.docs.isNotEmpty) {
      return chat.docs.first.id;
    }

    var chatId = await createIndividualChat(userId: opponentUserId);
    return chatId;
  }

  static Future<void> updateGroupChat({
    required String chatId,
    required String title,
    String? description,
    required List<String> participantIds,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final uid = await Spdb.getUid();

      if (cid == null || uid == null) {
        throw 'Invalid session';
      }

      final participantsKey = (participantIds..sort()).join('_');

      await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .update({
            'title': title,
            'description': description,
            'participants': participantIds,
            'participantsKey': participantsKey,
            'updatedAt': DateTime.now(),
            'lastMessage': LastMessageModel(
              message: 'Group details updated',
              senderId: uid,
              timestamp: DateTime.now(),
            ).toMap(),
          });
    } catch (e, st) {
      debugPrint('updateGroupChat error: $e\n$st');
      await ErrorService.recordError(e, st);
      throw 'Failed to update group chat';
    }
  }
}

/// Re-runs seen-marking for the open chat when the app comes back to the
/// foreground (see ChatService._isAppForeground).
class _SeenLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ChatService._onAppResumed();
  }
}