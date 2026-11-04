import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';

class ChatModel {
  final String? uid;
  final String createdBy;
  final List<String> participants;
  final String participantsKey;
  final String? title;
  final String? description;
  final bool isGroupChat;
  final LastMessageModel? lastMessage;
  final bool isPinned;
  final Map<String, dynamic>? isPinnedBy;
  final bool isFavorite;
  final Map<String, dynamic>? isFavoriteBy;
  final List<String>? deletedFor;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, String>? roles;
  final bool isAnnouncementChannel;

  ChatModel({
    this.uid,
    required this.createdBy,
    required this.participants,
    required this.participantsKey,
    this.title,
    this.description,
    this.isGroupChat = false,
    this.lastMessage,
    required this.isPinned,
    this.isPinnedBy,
    required this.isFavorite,
    this.isFavoriteBy,
    this.deletedFor,
    this.createdAt,
    this.updatedAt,
    this.roles,
    this.isAnnouncementChannel = false,
  });

  ChatModel copyWith({
    String? uid,
    String? createdBy,
    List<String>? participants,
    String? participantsKey,
    String? title,
    String? description,
    bool? isGroupChat,
    LastMessageModel? lastMessage,
    Map<String, List<String>>? reactions,
    bool? isPinned,
    Map<String, dynamic>? isPinnedBy,
    bool? isFavorite,
    Map<String, dynamic>? isFavoriteBy,
    List<String>? deletedFor,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? roles,
    bool? isAnnouncementChannel,
  }) {
    return ChatModel(
      uid: uid ?? this.uid,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      participantsKey: participantsKey ?? this.participantsKey,
      title: title ?? this.title,
      description: description ?? this.description,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      lastMessage: lastMessage ?? this.lastMessage,
      isPinned: isPinned ?? this.isPinned,
      isPinnedBy: isPinnedBy ?? this.isPinnedBy,
      isFavorite: isFavorite ?? this.isFavorite,
      isFavoriteBy: isFavoriteBy ?? this.isFavoriteBy,
      deletedFor: deletedFor ?? this.deletedFor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roles: roles ?? this.roles,
      isAnnouncementChannel:
          isAnnouncementChannel ?? this.isAnnouncementChannel,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'createdBy': createdBy,
      'participants': participants,
      'participantsKey': participantsKey,
      'title': title,
      'description': description,
      'isGroupChat': isGroupChat,
      'lastMessage': lastMessage?.toMap(),
      'isPinned': isPinned,
      'isPinnedBy': isPinnedBy,
      'isFavorite': isFavorite,
      'isFavoriteBy': isFavoriteBy,
      'deletedFor': deletedFor,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'roles': roles,
      'isAnnouncementChannel': isAnnouncementChannel,
    };
  }

  factory ChatModel.fromMap(String uid, Map<String, dynamic> map) {
    return ChatModel(
      uid: uid,
      createdBy: map['createdBy'] is String ? map['createdBy'] as String : '',
      participants: map['participants'] != null && map['participants'] is List
          ? List<String>.from(
              (map['participants'] as List).map((e) => e.toString()),
            )
          : [],
      participantsKey:
          map['participantsKey'] != null && map['participantsKey'] is String
          ? map['participantsKey'] as String
          : '',
      title: map['title'] != null && map['title'] is String
          ? map['title'] as String
          : null,
      description: map['description'] != null && map['description'] is String
          ? map['description'] as String
          : null,
      isGroupChat: map['isGroupChat'] is bool
          ? map['isGroupChat'] as bool
          : false,
      lastMessage:
          map['lastMessage'] != null &&
              map['lastMessage'] is Map<String, dynamic>
          ? LastMessageModel.fromMap(map['lastMessage'] as Map<String, dynamic>)
          : null,
      isPinned: map['isPinned'] != null ? map['isPinned'] as bool : false,
      isPinnedBy: map['isPinnedBy'] != null
          ? Map<String, dynamic>.from(map['isPinnedBy'])
          : {},
      isFavorite: map['isFavorite'] != null ? map['isFavorite'] as bool : false,
      isFavoriteBy: map['isFavoriteBy'] != null
          ? Map<String, dynamic>.from(map['isFavoriteBy'])
          : {},
      deletedFor: map['deletedFor'] != null
          ? List<String>.from(map['deletedFor'])
          : [],
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      roles: map['roles'] != null
          ? Map<String, String>.from(
              (map['roles'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            )
          : null,
      isAnnouncementChannel: map['isAnnouncementChannel'] is bool
          ? map['isAnnouncementChannel'] as bool
          : false,
    );
  }

  String getUserRole(String userId) {
    if (roles != null && roles!.containsKey(userId)) {
      return roles![userId]!;
    }
    return userId == createdBy ? 'owner' : 'member';
  }

  bool canPostMessage(String userId) {
    if (!isAnnouncementChannel) return true;
    final role = getUserRole(userId);
    return role == 'owner' || role == 'admin';
  }

  String toJson() => json.encode(toMap());

  factory ChatModel.fromJson(String uid, String source) =>
      ChatModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  bool isFavoriteForUser(String uid) {
    return isFavoriteBy?[uid] ?? isFavorite;
  }

  bool isPinnedForUser(String uid) {
    return isPinnedBy?[uid] == true;
  }

  bool isDeletedForUser(String uid) {
    return deletedFor?.contains(uid) ?? false;
  }

  @override
  String toString() {
    return 'ChatModel(uid: $uid, createdBy: $createdBy, participants: $participants, title: $title, description: $description, isGroupChat: $isGroupChat, lastMessage: $lastMessage, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

class MessagesModel {
  final String? uid;
  final String chatId;
  final String senderId;
  final String? senderName;
  String message;
  final List<String> receiverId;
  final List<FileModel> attachments;
  final bool edited;
  final List<MessagesEditHistory> editHistory;
  final String? replyFor;
  final String? replyForMessageId;
  final String? forwardFrom;
  final String? forwardFromMessageId;
  final String? forwardFromChatId;
  final List<String> seenBy;
  final Map<String, List<String>> reactions;
  final List<String> deletedFor;
  final bool isPinned;
  final DateTime? pinnedTimeStamp;
  final List<MentionModel>? mentions;
  final DateTime timestamp;
  final List<String> searchKeywords;
  final String? threadId;

  MessagesModel({
    this.uid,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.receiverId,
    required this.message,
    this.attachments = const [],
    this.edited = false,
    this.editHistory = const [],
    this.replyFor,
    this.replyForMessageId,
    this.forwardFrom,
    this.forwardFromMessageId,
    this.forwardFromChatId,
    this.seenBy = const [],
    this.reactions = const {},
    this.deletedFor = const [],
    this.isPinned = false,
    this.pinnedTimeStamp,
    this.mentions,
    DateTime? timestamp,
    this.searchKeywords = const [],
    this.threadId,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'message': message,
      'attachments': attachments.map((x) => x.toMap()).toList(),
      'edited': edited,
      'editHistory': editHistory.map((x) => x.toMap()).toList(),
      'replyFor': replyFor,
      'replyForMessageId': replyForMessageId,
      'forwardFrom': forwardFrom,
      'forwardFromMessageId': forwardFromMessageId,
      'forwardFromChatId': forwardFromChatId,
      'seenBy': seenBy,
      'reactions': reactions,
      'deletedFor': deletedFor,
      'isPinned': isPinned,
      'pinnedTimeStamp': pinnedTimeStamp?.millisecondsSinceEpoch,
      'mentions': mentions?.map((e) => e.toMap()).toList(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'searchKeywords': [
        ...buildSearchKeywords(message),
        ...attachments.expand((f) => buildSearchKeywords(f.name)),
      ],
      'threadId': threadId,
    };
  }

  factory MessagesModel.fromMap(String id, Map<String, dynamic> map) {
    return MessagesModel(
      uid: id,
      chatId: map['chatId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      receiverId: List<String>.from(map['receiverId'] ?? []),
      message: map['message'],
      attachments: (map['attachments'] as List? ?? [])
          .map((e) => FileModel.fromMap(e))
          .toList(),
      edited: map['edited'] ?? false,
      replyFor: map['replyFor'],
      replyForMessageId: map['replyForMessageId'],
      forwardFrom: map['forwardFrom'],
      forwardFromMessageId: map['forwardFromMessageId'],
      forwardFromChatId: map['forwardFromChatId'],
      seenBy: List<String>.from(map['seenBy'] ?? []),
      reactions: map['reactions'] != null
          ? Map<String, List<String>>.from(
              (map['reactions'] as Map).map(
                (k, v) => MapEntry(k, List<String>.from(v)),
              ),
            )
          : {},
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      isPinned: map['isPinned'] ?? false,
      mentions: (map['mentions'] as List?)
          ?.map((e) => MentionModel.fromMap(e))
          .toList(),
      pinnedTimeStamp: map['pinnedTimeStamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['pinnedTimeStamp'])
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      threadId: map['threadId'],
    );
  }

  Map<String, dynamic> toEditMap() {
    return {
      'message': message,
      'edited': true,
      'attachments': FieldValue.arrayUnion(
        attachments.map((x) => x.toMap()).toList(),
      ),
      'editHistory': FieldValue.arrayUnion(
        editHistory.map((x) => x.toMap()).toList(),
      ),
    };
  }
}

class LastMessageModel {
  final String senderId;
  final String? messageId;
  final String message;
  final String? type;
  final DateTime? timestamp;
  final List<FileModel>? attachments;
  LastMessageModel({
    required this.senderId,
    this.messageId,
    required this.message,
    this.type,
    this.timestamp,
    this.attachments,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'senderId': senderId,
      'messageId': messageId,
      'message': message,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'attachments': attachments?.map((x) => x.toMap()).toList(),
    };
  }

  factory LastMessageModel.fromMap(Map<String, dynamic> map) {
    return LastMessageModel(
      senderId: map['senderId'] as String,
      messageId: map['messageId'] as String?,
      message: map['message'] as String,
      type: map['type'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : null,
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((e) => FileModel.fromMap(e))
              .toList()
          : null,
    );
  }

  factory LastMessageModel.empty() {
    return LastMessageModel(senderId: '', message: '');
  }
}

class MessagesEditHistory {
  final String message;
  final DateTime? timestamp;
  MessagesEditHistory({required this.message, this.timestamp});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory MessagesEditHistory.fromMap(Map<String, dynamic> map) {
    return MessagesEditHistory(
      message: map['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

List<String> buildSearchKeywords(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toSet() // avoid duplicates
      .toList();
}

class MentionModel {
  final String uid;
  final String name;
  final String? image;
  final int? start;
  final int? end;

  MentionModel({
    required this.uid,
    required this.name,
    this.image,
    this.start,
    this.end,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'image': image,
      'start': start,
      'end': end,
    };
  }

  factory MentionModel.fromMap(Map<String, dynamic> map) {
    return MentionModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      image: map['image'],
      start: map['start'],
      end: map['end'],
    );
  }
}
