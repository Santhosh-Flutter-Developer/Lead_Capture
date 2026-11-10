import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/models/models.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Chat via chats.php (REST, polled – the backend has no realtime channel).
/// Server rules: unread/seen is tracked server side (fetching `messages`
/// marks them read), group edit = name + members only, no threads, no typing
/// indicator, no per-message "delete for me".
class ChatService {
  // ── caches shared by the UI ────────────────────────────────────────────
  static final ValueNotifier<int> _unviewedCount = ValueNotifier<int>(0);
  static final ValueNotifier<Map<String, int>> _unviewedByChat =
      ValueNotifier<Map<String, int>>(<String, int>{});
  static Map<String, int> _rawUnviewed = <String, int>{};
  static String? _activeChatId;

  static List<ChatModel> _lastChats = [];
  static final Map<String, List<String>> _groupMembers = {};
  static final Map<String, List<MessagesModel>> _lastMessages = {};
  static final Map<String, Uint8List> _pendingBytes = {};

  static Never _unsupported(String what) =>
      throw '$what is not supported by the server API.';
  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  // ── threads (chat list) ────────────────────────────────────────────────
  static Future<List<ChatModel>> _fetchThreads() async {
    final myUid = await Spdb.getUid() ?? '';
    final res = (await ChatsApiService.threads()).ensureSuccess();
    final rows = Js.mapList(res.dataMap['threads']);

    // Threads do not list group members -> load once per group and cache.
    final missing = rows
        .where((r) => Js.b(r['is_group']) && !_groupMembers.containsKey(Js.s(r['chat_uid'])))
        .map((r) => Js.s(r['chat_uid']))
        .toList();
    await Future.wait(missing.map((id) async {
      try {
        final g = (await ChatsApiService.groupMembers(id)).ensureSuccess();
        _groupMembers[id] =
            Js.mapList(g.dataMap['members']).map((u) => Js.s(u['uid'])).toList();
      } catch (e) {
        debugPrint('group_members failed for $id: $e');
      }
    }));

    final unread = <String, int>{};
    final chats = rows.map((r) {
      final id = Js.s(r['chat_uid']);
      final n = Js.i(r['unread_count']) ?? 0;
      if (n > 0) unread[id] = n;
      return ChatMappers.thread(r, myUid: myUid, members: _groupMembers[id]);
    }).toList();

    _lastChats = chats;
    _publishUnviewed(unread);
    return chats;
  }

  static StreamController<List<ChatModel>>? _threadsCtrl;
  static StreamSubscription<List<ChatModel>>? _threadsSub;

  /// One shared poller (15 s + after any chat mutation) for the chat list
  /// and the unread badges.
  static void _ensureThreadsPoller() {
    if (_threadsSub != null) return;
    _threadsCtrl ??= StreamController<List<ChatModel>>.broadcast();
    _threadsSub = ApiLive.watch<List<ChatModel>>(
      {'chats'},
      _fetchThreads,
      interval: const Duration(seconds: 15),
    ).listen(
      (c) => _threadsCtrl!.add(c),
      onError: (Object e, StackTrace st) => _threadsCtrl!.addError(e, st),
    );
  }

  /// Chat list stream for ChatBloc.
  static Stream<List<ChatModel>> watchChats() async* {
    _ensureThreadsPoller();
    if (_lastChats.isNotEmpty) yield _lastChats;
    yield* _threadsCtrl!.stream;
  }

  /// Stops polling (call on logout).
  static Future<void> reset() async {
    await _threadsSub?.cancel();
    _threadsSub = null;
    _lastChats = [];
    _groupMembers.clear();
    _lastMessages.clear();
    _publishUnviewed(<String, int>{});
  }

  // ── unread badges ──────────────────────────────────────────────────────
  static ValueListenable<int> unviewedCount() {
    _ensureThreadsPoller();
    return _unviewedCount;
  }

  static ValueListenable<Map<String, int>> unviewedByChat() {
    _ensureThreadsPoller();
    return _unviewedByChat;
  }

  static void setActiveChat(String? chatId) {
    _activeChatId = (chatId == null || chatId.isEmpty) ? null : chatId;
    scheduleMicrotask(_republishUnviewed);
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
    final active = _activeChatId;
    if (active != null && (counts[active] ?? 0) > 0) {
      markChatMessagesAsSeen(active);
    }
  }

  static void _republishUnviewed() {
    final visible = Map<String, int>.from(_rawUnviewed);
    if (_activeChatId != null) visible.remove(_activeChatId);
    if (!mapEquals(visible, _unviewedByChat.value)) {
      _unviewedByChat.value = visible;
    }
    final total = visible.values.fold<int>(0, (a, b) => a + b);
    if (total != _unviewedCount.value) _unviewedCount.value = total;
  }

  // ── messages ───────────────────────────────────────────────────────────
  /// Newest first (same order the UI always received).
  static Future<List<MessagesModel>> _fetchMessages(String chatUid) async {
    final res = (await ChatsApiService.messages(chatUid)).ensureSuccess();
    final chat = await getChat(uid: chatUid);
    final receivers = chat?.participants ?? const <String>[];
    final list = Js.mapList(res.dataMap['messages'])
        .map((m) => ChatMappers.message(m, receivers: receivers))
        .toList()
        .reversed
        .toList();
    _lastMessages[chatUid] = list;
    return list;
  }

  static Stream<List<MessagesModel>> getChatMessagesStream({
    required String uid,
    int? limit,
  }) {
    return ApiLive.watch<List<MessagesModel>>(
      {'chat:$uid'},
      () async {
        final all = await _fetchMessages(uid);
        // `messages` marks everything read on the server -> refresh badges.
        if ((_rawUnviewed[uid] ?? 0) > 0) ApiLive.changed({'chats'});
        return limit == null ? all : all.take(limit).toList();
      },
      interval: const Duration(seconds: 5),
    );
  }

  /// The API returns the latest 300 messages in one go (no paging).
  static Future<List<MessagesModel>> getChatMessagesPage({
    required String uid,
    required int limit,
    required DateTime lastTimestamp,
  }) async {
    final all = _lastMessages[uid] ?? await _fetchMessages(uid);
    return all.where((m) => m.timestamp.isBefore(lastTimestamp)).take(limit).toList();
  }

  /// Threads (replies in a side thread) do not exist in the API.
  static Stream<List<MessagesModel>> getThreadMessagesStream({
    required String chatId,
    required String parentMessageId,
  }) =>
      Stream.value(<MessagesModel>[]);

  static Future<List<MessagesModel>> getChatMessages({required String uid}) =>
      _fetchMessages(uid);

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
    return messages.where((m) {
      final hay = '${m.message} ${m.attachments.map((a) => a.name).join(' ')}'.toLowerCase();
      return terms.every(hay.contains);
    }).toList();
  }

  /// Seen state is server side: fetching `messages` marks them read.
  static Future<void> updateSeenChat({
    required String chatId,
    required String messageId,
  }) =>
      markChatMessagesAsSeen(chatId);

  static final Set<String> _seenRunning = {};

  static Future<void> markChatMessagesAsSeen(String chatId) async {
    if (chatId.isEmpty || !_seenRunning.add(chatId)) return;
    try {
      await ChatsApiService.messages(chatId);
      _rawUnviewed = Map<String, int>.from(_rawUnviewed)..remove(chatId);
      _republishUnviewed();
      ApiLive.changed({'chats'});
    } catch (e) {
      debugPrint('markChatMessagesAsSeen failed: $e');
    } finally {
      _seenRunning.remove(chatId);
    }
  }

  /// No typing indicator endpoint exists.
  static Future<void> updateTypingOnChat({
    required String chatId,
    required bool status,
  }) async {}

  static Future<MessagesModel> getChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    var list = _lastMessages[chatId];
    MessagesModel? hit() {
      for (final m in list ?? const <MessagesModel>[]) {
        if (m.uid == messageId) return m;
      }
      return null;
    }

    var m = hit();
    if (m == null) {
      list = await _fetchMessages(chatId);
      m = hit();
    }
    if (m == null) throw 'Message not found';
    return m;
  }

  static int _id(String messageId) {
    final id = int.tryParse(messageId);
    if (id == null) throw 'Message is still sending, try again in a moment.';
    return id;
  }

  static Future<MessagesModel?> deleteChatMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final before = _lastMessages[chatId]?.where((m) => m.uid == messageId);
      (await ChatsApiService.call('delete_message', {'message_id': _id(messageId)}))
          .ensureSuccess();
      ApiLive.changed({'chat:$chatId', 'chats'});
      return (before != null && before.isNotEmpty) ? before.first : null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting message: ${_msg(e)}';
    }
  }

  static Future<void> editChatMessage({
    required String uid,
    required String message,
    required String chatId,
    List<FileModel>? attachments,
  }) async {
    try {
      (await ChatsApiService.call('edit_message', {
        'message_id': _id(uid),
        'message': message,
      }))
          .ensureSuccess();
      ApiLive.changed({'chat:$chatId', 'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error editing message: ${_msg(e)}';
    }
  }

  /// Remembers raw bytes of a chat upload so [sendChatMessage] can post the
  /// file to chats.php (it only accepts multipart files, not URLs).
  static void cacheUploadBytes(String url, Uint8List bytes) {
    _pendingBytes[url] = bytes;
  }

  static Future<ApiUploadFile> _fileFor(FileModel f) async {
    var bytes = _pendingBytes.remove(f.url);
    if (bytes == null) {
      final r = await http.get(Uri.parse(f.url));
      if (r.statusCode != 200) throw 'Could not read attachment ${f.name}';
      bytes = r.bodyBytes;
    }
    return ApiUploadFile(field: 'attachments[]', fileName: f.name, bytes: bytes);
  }

  static Future<void> sendChatMessage({
    required String chatId,
    required String message,
    List<FileModel>? attachments,
    String? replyFor,
    List<MentionModel>? mentions,
    String? threadId,
    String? messageId,
    DateTime? timestamp,
    List<String>? participants,
    String? forwardFrom,
    String? forwardFromMessageId,
    String? forwardFromChatId,
  }) async {
    try {
      final files = attachments ?? const <FileModel>[];
      String? snippet;
      int? replyId;
      if (replyFor != null && replyFor.isNotEmpty) {
        replyId = int.tryParse(replyFor);
        final src = _lastMessages[chatId]?.where((m) => m.uid == replyFor);
        if (src != null && src.isNotEmpty) {
          final m = src.first;
          snippet = m.message.isNotEmpty
              ? m.message
              : (m.attachments.isNotEmpty ? m.attachments.first.name : null);
        }
      }
      (await ChatsApiService.sendMessage(
        chatUid: chatId,
        message: message,
        replyToId: replyId,
        replyToSnippet: snippet,
        files: await Future.wait(files.map(_fileFor)),
      ))
          .ensureSuccess();
      ApiLive.changed({'chat:$chatId', 'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error sending chat message: ${_msg(e)}';
    }
  }

  /// The server creates the chat notification itself; nothing to send.
  static Future<void> sendNotification({
    required String chatId,
    required String message,
    bool? isChat,
    String? messageId,
  }) async {}

  // ── chats ──────────────────────────────────────────────────────────────
  /// Every chat I'm a member of (cached list, fetched when empty).
  static Future<List<ChatModel>> getMyChats() async =>
      _lastChats.isNotEmpty ? _lastChats : await _fetchThreads();

  static Future<ChatModel?> getChat({required String uid}) async {
    try {
      return await _getChat(uid: uid);
    } catch (_) {
      return null;
    }
  }

  static Future<ChatModel> _getChat({required String uid}) async {
    for (final c in _lastChats) {
      if (c.uid == uid) return c;
    }
    final fresh = await _fetchThreads();
    for (final c in fresh) {
      if (c.uid == uid) return c;
    }
    throw 'Chat not found';
  }

  static Future<List<ChatModel>> getChatGroups() async {
    try {
      final chats = _lastChats.isNotEmpty ? _lastChats : await _fetchThreads();
      return chats.where((c) => c.isGroupChat).toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching chat groups: ${_msg(e)}';
    }
  }

  static Future<String?> createGroupChat({required ChatModel model}) async {
    try {
      final me = await Spdb.getUid();
      final res = (await ChatsApiService.call('create_group', {
        'group_name': model.title ?? '',
        'members': model.participants.where((u) => u != me).toList(),
      }))
          .ensureSuccess();
      ApiLive.changed({'chats'});
      return Js.opt(res.dataMap['chat_uid']);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error creating group chat: ${_msg(e)}';
    }
  }

  static Future<String> createIndividualChat({required String userId}) async {
    try {
      final me = await Spdb.getUid();
      if (me == null || me.isEmpty || userId.isEmpty) throw 'Invalid chat users';
      final res = (await ChatsApiService.call('create_direct', {'target_uid': userId}))
          .ensureSuccess();
      final id = Js.s(res.dataMap['chat_uid']);
      if (id.isEmpty) throw 'Chat could not be created';
      ApiLive.changed({'chats'});
      return id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error creating chat: ${_msg(e)}';
    }
  }

  static Future<String?> getChatUid(String opponentUserId) async {
    final me = await Spdb.getUid();
    if (me == opponentUserId) return null;
    return createIndividualChat(userId: opponentUserId);
  }

  static Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    (await ChatsApiService.call('react_message', {
      'message_id': _id(messageId),
      'emoji': emoji,
    }))
        .ensureSuccess();
    ApiLive.changed({'chat:$chatId'});
  }

  /// Pins / unpins a MESSAGE (server toggles).
  static Future<void> togglePin({
    required String chatId,
    required String messageId,
    required bool value,
  }) async {
    final cur = _lastMessages[chatId]?.where((m) => m.uid == messageId);
    if (cur != null && cur.isNotEmpty && cur.first.isPinned == value) return;
    (await ChatsApiService.call('toggle_pin_message', {'message_id': _id(messageId)}))
        .ensureSuccess();
    ApiLive.changed({'chat:$chatId'});
  }

  static Future<ChatModel?> _cached(String chatId) async {
    for (final c in _lastChats) {
      if (c.uid == chatId) return c;
    }
    return null;
  }

  /// Pins / unpins a CHAT for me (server toggles).
  static Future<void> toggleChatPin({
    required String chatId,
    required bool value,
  }) async {
    try {
      final c = await _cached(chatId);
      if (c != null && c.isPinned == value) return;
      (await ChatsApiService.call('toggle_pin', {'chat_uid': chatId})).ensureSuccess();
      ApiLive.changed({'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error pinning chat: ${_msg(e)}';
    }
  }

  static Future<void> toggleChatFavorite({
    required String chatId,
    required bool value,
  }) async {
    try {
      final c = await _cached(chatId);
      if (c != null && c.isFavorite == value) return;
      (await ChatsApiService.call('toggle_favorite', {'chat_uid': chatId})).ensureSuccess();
      ApiLive.changed({'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error updating favourite: ${_msg(e)}';
    }
  }

  static Future<void> deleteChat({required String chatId}) async {
    try {
      (await ChatsApiService.call('delete_chat', {'chat_uid': chatId})).ensureSuccess();
      ApiLive.changed({'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting chat: ${_msg(e)}';
    }
  }

  static Future<void> restoreChat(ChatModel chat) async {
    final id = chat.uid;
    if (id == null || id.isEmpty) throw Exception('Chat UID missing');
    (await ChatsApiService.call('restore_chat', {'chat_uid': id})).ensureSuccess();
    ApiLive.changed({'chats'});
  }

  static Future<void> clearChat({required String chatId}) async {
    (await ChatsApiService.call('clear_chat', {'chat_uid': chatId})).ensureSuccess();
    ApiLive.changed({'chat:$chatId', 'chats'});
  }

  static Future<void> leaveGroup({required String chatId}) async {
    (await ChatsApiService.call('leave_group', {'chat_uid': chatId})).ensureSuccess();
    _groupMembers.remove(chatId);
    ApiLive.changed({'chats'});
  }

  /// Delivered count. Uses chats.php `forward_message` (the server copies the
  /// message/attachments into each target chat).
  static Future<int> forwardMessage({
    required MessagesModel source,
    required String sourceChatId,
    List<String> targetChatIds = const [],
    List<String> targetUserIds = const [],
  }) async {
    final chatIds = <String>[...targetChatIds];
    for (final userId in targetUserIds) {
      try {
        final id = await createIndividualChat(userId: userId);
        if (!chatIds.contains(id)) chatIds.add(id);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
      }
    }
    if (chatIds.isEmpty) return 0;
    try {
      (await ChatsApiService.call('forward_message', {
        'message_id': _id(source.uid ?? ''),
        'target_chat_uids': chatIds,
      }))
          .ensureSuccess();
      ApiLive.changed({'chats', ...chatIds.map((c) => 'chat:$c')});
      return chatIds.length;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error forwarding message: ${_msg(e)}';
    }
  }

  /// Group name + members (description is not stored by the server).
  static Future<void> updateGroupChat({
    required String chatId,
    required String title,
    String? description,
    required List<String> participantIds,
  }) async {
    try {
      (await ChatsApiService.call('update_group', {
        'chat_uid': chatId,
        'group_name': title,
        'members': participantIds,
      }))
          .ensureSuccess();
      _groupMembers.remove(chatId);
      ApiLive.changed({'chats'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error updating group: ${_msg(e)}';
    }
  }
}
