// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';

class BackupModel {
  final String? uid;
  final UserDataModel intiatedBy;
  final String parentCollectionId;
  final String path;
  final String type;
  final int size;
  final DateTime timestamp;
  final String url;
  BackupModel({
    this.uid,
    required this.intiatedBy,
    required this.parentCollectionId,
    required this.path,
    required this.type,
    required this.size,
    required this.timestamp,
    required this.url,
  });

  BackupModel copyWith({
    String? uid,
    UserDataModel? intiatedBy,
    String? parentCollectionId,
    String? path,
    String? type,
    int? size,
    DateTime? timestamp,
    String? url,
  }) {
    return BackupModel(
      uid: uid ?? this.uid,
      intiatedBy: intiatedBy ?? this.intiatedBy,
      parentCollectionId: parentCollectionId ?? this.parentCollectionId,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      timestamp: timestamp ?? this.timestamp,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'intiatedBy': intiatedBy.toMap(),
      'parentCollectionId': parentCollectionId,
      'path': path,
      'type': type,
      'size': size,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'url': url,
    };
  }

  factory BackupModel.fromMap(Map<String, dynamic> map) {
    return BackupModel(
      uid: map['uid'] as String?,
      intiatedBy: map['intiatedBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['intiatedBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      parentCollectionId: map['parentCollectionId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      type: map['type'] as String? ?? '',
      size: map['size'] as int? ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      url: map['url'] as String? ?? '',
    );
  }

  factory BackupModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return BackupModel(
      uid: doc.id,
      intiatedBy: map['intiatedBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['intiatedBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      parentCollectionId: map['parentCollectionId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      type: map['type'] as String? ?? '',
      size: map['size'] as int? ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      url: map['url'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory BackupModel.fromJson(String source) =>
      BackupModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'BackupModel(uid: $uid, intiatedBy: $intiatedBy, parentCollectionId: $parentCollectionId, path: $path, type: $type, size: $size, timestamp: $timestamp, url: $url)';
  }

  @override
  bool operator ==(covariant BackupModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.intiatedBy == intiatedBy &&
        other.parentCollectionId == parentCollectionId &&
        other.path == path &&
        other.type == type &&
        other.size == size &&
        other.timestamp == timestamp &&
        other.url == url;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        intiatedBy.hashCode ^
        parentCollectionId.hashCode ^
        path.hashCode ^
        type.hashCode ^
        size.hashCode ^
        timestamp.hashCode ^
        url.hashCode;
  }
}
