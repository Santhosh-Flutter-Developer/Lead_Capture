import 'dart:convert';
import 'package:leadcapture/models/src/chat_model.dart';

import '/constants/constants.dart';

  class NotificationModel {
    final String? uid;

    // Backend
    final String? collectionId;

    // Common fields
    final String title;
    final String body;
    final String? img;
    final NotificationType? type;
    final DateTime? createdAt;

    // Targets
    final List<String> to;
    final List<String> toFcms;
    final List<String> toUids;

    // Per-user read tracking (uids of users who have already seen this)
    final List<String> readBy;

    // Chat
    final bool isChat;
    final MessagesModel? message;
    final ChatModel? chat;

    // Permission
    final bool? isPermissionRequest;

    // Extra
    final String? senderId;
    final Map<String, dynamic> payload;

    NotificationModel({
      this.uid,
      this.collectionId,
      required this.title,
      required this.body,
      this.img,
      this.type,
      this.createdAt,
      this.to = const [],
      this.toFcms = const [],
      this.toUids = const [],
      this.readBy = const [],
      this.isChat = false,
      this.message,
      this.chat,
      this.isPermissionRequest,
      this.senderId,
      this.payload = const {},
    });

    // ---------------- COPY ----------------

    NotificationModel copyWith({
      String? uid,
      String? collectionId,
      String? title,
      String? body,
      String? img,
      NotificationType? type,
      DateTime? createdAt,
      List<String>? to,
      List<String>? toFcms,
      List<String>? toUids,
      List<String>? readBy,
      bool? isChat,
      MessagesModel? message,
      ChatModel? chat,
      bool? isPermissionRequest,
      String? senderId,
      Map<String, dynamic>? payload,
    }) {
      return NotificationModel(
        uid: uid ?? this.uid,
        collectionId: collectionId ?? this.collectionId,
        title: title ?? this.title,
        body: body ?? this.body,
        img: img ?? this.img,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        to: to ?? this.to,
        toFcms: toFcms ?? this.toFcms,
        toUids: toUids ?? this.toUids,
        readBy: readBy ?? this.readBy,
        isChat: isChat ?? this.isChat,
        message: message ?? this.message,
        chat: chat ?? this.chat,
        isPermissionRequest: isPermissionRequest ?? this.isPermissionRequest,
        senderId: senderId ?? this.senderId,
        payload: payload ?? this.payload,
      );
    }

    // ---------------- MAP ----------------

    Map<String, dynamic> toMap() {
      return {
        'collectionId': collectionId,
        'title': title,
        'body': body,
        'img': img,
        'type': type?.name,
        'createdAt':
            createdAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        'to': to,
        'toFcms': toFcms,
        'toUids': toUids,
        'readBy': readBy,
        'isChat': isChat,
        'message': message?.toMap(),
        'chat': chat?.toMap(),
        'isPermissionRequest': isPermissionRequest,
        'senderId': senderId,
        'payload': payload,
      };
    }

    factory NotificationModel.fromMap(String uid, Map<String, dynamic> map) {
      return NotificationModel(
        uid: uid,
        collectionId: map['collectionId'] ?? '',
        title: map['title'] ?? '',
        body: map['body'] ?? map['message'] ?? '',
        img: map['img'],
        type: map['type'] != null
            ? NotificationType.values.byName(map['type'])
            : null,
        createdAt: map['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
            : null,
        to: map['to'] != null ? List<String>.from(map['to']) : [],
        toFcms: map['toFcms'] != null ? List<String>.from(map['toFcms']) : [],
        toUids: map['toUids'] != null ? List<String>.from(map['toUids']) : [],
        readBy: map['readBy'] != null ? List<String>.from(map['readBy']) : [],
        isChat: map['isChat'] ?? false,
        message: map['message'] != null
            ? MessagesModel.fromMap('', Map<String, dynamic>.from(map['message']))
            : null,

        chat: map['chat'] != null
            ? ChatModel.fromMap(
                map['chat']['uid'],
                Map<String, dynamic>.from(map['chat']),
              )
            : null,
        isPermissionRequest: map['isPermissionRequest'],
        senderId: map['senderId'],
        payload: map['payload'] != null
            ? Map<String, dynamic>.from(map['payload'])
            : {},
      );
    }

    String toJson() => json.encode(toMap());

    @override
    bool operator ==(covariant NotificationModel other) {
      if (identical(this, other)) return true;

      return other.uid == uid &&
          other.collectionId == collectionId &&
          other.title == title &&
          other.body == body;
    }

    @override
    int get hashCode =>
        uid.hashCode ^ collectionId.hashCode ^ title.hashCode ^ body.hashCode;
  }