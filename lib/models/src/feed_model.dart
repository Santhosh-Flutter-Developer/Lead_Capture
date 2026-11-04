import 'package:cloud_firestore/cloud_firestore.dart';

import '/models/models.dart';

DateTime _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  return DateTime.now();
}

dynamic _dateTimeToValue(DateTime? value) {
  return value?.toIso8601String();
}

class FeedModel {
  final String? uid;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<FileModel> mediaImages;
  final List<FileModel> attachments;
  final List<TaggedUserModel> taggedUsers;
  final PollModel? poll;
  final List<ReactionModel> reactions;
  final List<String> savedBy;
  final int commentsCount;
  final List<CommentModel>? comments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FeedModel({
    this.uid,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    DateTime? createdAt,
    required List<FileModel> mediaImages,
    required List<FileModel> attachments,
    required List<TaggedUserModel> taggedUsers,
    required List<ReactionModel> reactions,
    List<String> savedBy = const [],
    this.poll,
    this.commentsCount = 0,
    List<CommentModel>? comments,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       mediaImages = List<FileModel>.from(mediaImages),
       attachments = List<FileModel>.from(attachments),
       taggedUsers = List<TaggedUserModel>.from(taggedUsers),
       reactions = List<ReactionModel>.from(reactions),
       savedBy = List<String>.from(savedBy),
       comments = comments != null ? List<CommentModel>.from(comments) : null;

  FeedModel copyWith({
    String? uid,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<FileModel>? mediaImages,
    List<FileModel>? attachments,
    List<TaggedUserModel>? taggedUsers,
    List<ReactionModel>? reactions,
    List<String>? savedBy,
    PollModel? poll,
    int? commentsCount,
    List<CommentModel>? comments,
  }) {
    return FeedModel(
      uid: uid ?? this.uid,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaImages: mediaImages ?? this.mediaImages,
      attachments: attachments ?? this.attachments,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      reactions: reactions ?? this.reactions,
      savedBy: savedBy ?? this.savedBy,
      poll: poll ?? this.poll,
      commentsCount: commentsCount ?? this.commentsCount,
      comments: comments ?? this.comments,
    );
  }

  factory FeedModel.fromMap(String uid, Map<String, dynamic> map) {
    return FeedModel(
      uid: uid,
      authorId: map['authorId'] != null && map['authorId'] is String
          ? map['authorId']
          : '',
      authorName: map['authorName'] != null && map['authorName'] is String
          ? map['authorName']
          : '',
      authorAvatar: map['authorAvatar'] != null && map['authorAvatar'] is String
          ? map['authorAvatar']
          : '',
      content: map['content'] != null && map['content'] is String
          ? map['content']
          : '',
      createdAt: _dateTimeFromValue(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? _dateTimeFromValue(map['updatedAt'])
          : null,
      mediaImages: map['mediaImages'] != null
          ? (map['mediaImages'] as List<dynamic>? ?? [])
                .map((x) => FileModel.fromMap(x))
                .toList()
          : [],
      attachments: map['attachments'] != null
          ? (map['attachments'] as List<dynamic>? ?? [])
                .map((x) => FileModel.fromMap(x))
                .toList()
          : [],
      taggedUsers: map['taggedUsers'] != null
          ? (map['taggedUsers'] as List<dynamic>? ?? [])
                .map((x) => TaggedUserModel.fromMap(x))
                .toList()
          : [],
      reactions: map['reactions'] != null
          ? (map['reactions'] as List<dynamic>? ?? [])
                .map((x) => ReactionModel.fromMap(x))
                .toList()
          : [],
      savedBy: map['savedBy'] != null
          ? (map['savedBy'] as List<dynamic>? ?? [])
                .map((x) => x.toString())
                .toList()
          : [],
      poll: map['poll'] != null ? PollModel.fromMap(map['poll']) : null,
      commentsCount: map['commentsCount'] != null && map['commentsCount'] is int
          ? map['commentsCount']
          : 0,
      comments: map['comments'] != null
          ? (map['comments'] as List<dynamic>? ?? [])
                .map((x) => CommentModel.fromMap(x))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': _dateTimeToValue(createdAt),
      'updatedAt': _dateTimeToValue(updatedAt),
      'mediaImages': mediaImages.map((e) => e.toMap()).toList(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'taggedUsers': taggedUsers.map((e) => e.toMap()).toList(),
      'reactions': reactions.map((e) => e.toMap()).toList(),
      'savedBy': savedBy,
      'poll': poll?.toMap(),
      'commentsCount': commentsCount,
      'comments': comments?.map((e) => e.toMap()).toList(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': _dateTimeToValue(createdAt),
      'updatedAt': _dateTimeToValue(updatedAt),
      'mediaImages': mediaImages.map((e) => e.toMap()).toList(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'taggedUsers': taggedUsers.map((e) => e.toMap()).toList(),
      'reactions': reactions.map((e) => e.toMap()).toList(),
      'savedBy': savedBy,
      'poll': poll?.toMap(),
      'commentsCount': commentsCount,
      'comments': comments?.map((e) => e.toMap()).toList(),
    };
  }
}

class FeedHistoryModel {
  final DateTime timestamp;
  final String userId;
  final String action;
  final String? content;

  FeedHistoryModel({
    required this.userId,
    required this.action,
    this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'action': action,
      'content': content,
    };
  }

  factory FeedHistoryModel.fromMap(Map<String, dynamic> map) {
    return FeedHistoryModel(
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : map['timestamp'] is String
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      userId: map['userId']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      content: map['content']?.toString(),
    );
  }
}

class ReactionModel {
  final String userId;
  final String type;

  ReactionModel({required this.userId, required this.type});

  factory ReactionModel.fromMap(Map<String, dynamic> map) {
    return ReactionModel(
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'like',
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'type': type};
  }
}

class TaggedUserModel {
  final String userId;
  final String userName;

  TaggedUserModel({required this.userId, required this.userName});

  factory TaggedUserModel.fromMap(Map<String, dynamic> map) {
    return TaggedUserModel(
      userId: map['userId'] != null && map['userId'] is String
          ? map['userId']
          : '',
      userName: map['userName'] != null && map['userName'] is String
          ? map['userName']
          : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'userName': userName};
  }
}

class PollOption {
  final String optionId;
  final String title;
  int votes;

  PollOption({required this.optionId, required this.title, this.votes = 0});

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      optionId: map['optionId'],
      title: map['title'],
      votes: map['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'optionId': optionId, 'title': title, 'votes': votes};
  }
}

class PollModel {
  final String pollId;
  final String question;
  final List<PollOption> options;
  final List<String> votedUserIds;

  PollModel({
    required this.pollId,
    required this.question,
    required List<PollOption> options,
    List<String> votedUserIds = const [],
  }) : options = List<PollOption>.from(options),
       votedUserIds = List<String>.from(votedUserIds);

  factory PollModel.fromMap(Map<String, dynamic> map) {
    return PollModel(
      pollId: map['pollId'] ?? '',
      question: map['question'] ?? '',
      options: (map['options'] as List<dynamic>? ?? [])
          .map((x) => PollOption.fromMap(x))
          .toList(),
      votedUserIds: (map['votedUserIds'] as List<dynamic>? ?? [])
          .map((x) => x.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'question': question,
      'options': options.map((e) => e.toMap()).toList(),
      'votedUserIds': votedUserIds,
    };
  }
}

class CommentModel {
  final String commentId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String? replyToCommentId;
  final Map<String, List<String>> reactions;
  final DateTime createdAt;

  CommentModel({
    required this.commentId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.replyToCommentId,
    this.reactions = const {},
    required this.createdAt,
  });

  CommentModel copyWith({
    String? commentId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? replyToCommentId,
    Map<String, List<String>>? reactions,
    DateTime? createdAt,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      replyToCommentId: replyToCommentId ?? this.replyToCommentId,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      commentId: map['commentId'] != null && map['commentId'] is String
          ? map['commentId']
          : '',
      authorId: map['authorId'] != null && map['authorId'] is String
          ? map['authorId']
          : '',
      authorName: map['authorName'] != null && map['authorName'] is String
          ? map['authorName']
          : '',
      authorAvatar: map['authorAvatar'] != null && map['authorAvatar'] is String
          ? map['authorAvatar']
          : '',
      content: map['content'] != null && map['content'] is String
          ? map['content']
          : '',
      replyToCommentId: map['replyToCommentId'] as String?,
      reactions: map['reactions'] != null
          ? Map<String, List<String>>.from(
              (map['reactions'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), List<String>.from(value)),
              ),
            )
          : {},
      createdAt: map['createdAt'] != null && map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'replyToCommentId': replyToCommentId,
      'reactions': reactions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
