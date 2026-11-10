import 'dart:convert';
import '/models/models.dart';
import 'api_mappers.dart';
import 'crm_mappers.dart';

/// chats.php rows → ChatModel / MessagesModel.
class ChatMappers {
  ChatMappers._();

  static List<dynamic> _jsonList(dynamic v) {
    if (v is List) return v;
    if (v is String && v.trim().isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d;
      } catch (_) {}
    }
    return const [];
  }

  /// A `threads` row. [members] must be supplied for groups (threads does not
  /// return them); direct chats get [myUid, other_uid].
  static ChatModel thread(
    Map<String, dynamic> m, {
    required String myUid,
    List<String>? members,
  }) {
    final isGroup = Js.b(m['is_group']);
    final other = Js.s(m['other_uid']);
    final participants = isGroup
        ? (members ?? <String>[])
        : <String>[myUid, if (other.isNotEmpty && other != myUid) other];
    final pinned = Js.b(m['is_pinned']);
    final fav = Js.b(m['is_favorite']);
    final lastText = Js.s(m['last_message']);
    final lastAt = Js.dt(m['last_message_time']);
    final created = Js.dt(m['created_at']);
    final createdBy = Js.s(m['created_by']);
    return ChatModel(
      uid: Js.s(m['chat_uid']),
      createdBy: createdBy,
      participants: participants,
      participantsKey: ([...participants]..sort()).join('_'),
      title: isGroup ? Js.s(m['name']) : null,
      description: null,
      isGroupChat: isGroup,
      lastMessage: lastText.isEmpty && lastAt == null
          ? null
          : LastMessageModel(
              senderId: '',
              message: lastText,
              type: 'text',
              timestamp: lastAt,
            ),
      isPinned: pinned,
      isPinnedBy: {myUid: pinned},
      isFavorite: fav,
      isFavoriteBy: {myUid: fav},
      deletedFor: const [],
      createdAt: created ?? lastAt,
      updatedAt: lastAt ?? created,
      roles: createdBy.isEmpty ? null : {createdBy: 'owner'},
    );
  }

  /// A `messages` row (chat_messages table).
  static MessagesModel message(Map<String, dynamic> m, {List<String> receivers = const []}) {
    final attachments = _jsonList(m['attachments'])
        .whereType<Map>()
        .map((e) => CrmMappers.file(Map<String, dynamic>.from(e)))
        .toList();
    var text = Js.s(m['message']);
    if (attachments.isNotEmpty && RegExp(r'^\d+ attachment\(s\)$').hasMatch(text)) {
      text = '';
    }
    final reactions = <String, List<String>>{};
    for (final r in _jsonList(m['reactions']).whereType<Map>()) {
      final emoji = Js.s(r['emoji']);
      final uid = Js.s(r['uid']);
      if (emoji.isEmpty || uid.isEmpty) continue;
      reactions.putIfAbsent(emoji, () => []).add(uid);
    }
    final replyId = Js.s(m['reply_to_id']);
    return MessagesModel(
      uid: Js.s(m['id']),
      chatId: Js.s(m['chat_uid']),
      senderId: Js.s(m['sender_uid']),
      senderName: Js.s(m['sender_name']),
      receiverId: receivers,
      message: text,
      attachments: attachments,
      edited: Js.b(m['is_edited']),
      replyFor: replyId.isEmpty || replyId == '0' ? null : replyId,
      replyForMessageId: replyId.isEmpty || replyId == '0' ? null : replyId,
      seenBy: _jsonList(m['read_by']).map((e) => e.toString()).toList(),
      reactions: reactions,
      isPinned: Js.b(m['is_pinned']),
      pinnedTimeStamp: Js.dt(m['pinned_at']),
      timestamp: Js.dt(m['created_at']) ?? DateTime.now(),
    );
  }

  static List<String> memberUids(dynamic members) =>
      _jsonList(members).map((e) => e.toString()).toList();
}
