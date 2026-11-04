// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'user_data_model.dart';

class ActivityLogModel {
  final String? uid;
  final UserDataModel userData;
  final String activity;
  final String? description;
  final String? docId;
  final String collection;
  final DateTime createdAt;
  final DateTime updatedAt;
  ActivityLogModel({
    this.uid,
    required this.userData,
    required this.activity,
    this.description,
    this.docId,
    required this.collection,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ActivityLogModel copyWith({
    String? uid,
    UserDataModel? userData,
    String? activity,
    String? description,
    String? docId,
    String? collection,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityLogModel(
      uid: uid ?? this.uid,
      userData: userData ?? this.userData,
      activity: activity ?? this.activity,
      description: description ?? this.description,
      docId: docId ?? this.docId,
      collection: collection ?? this.collection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userData': userData.toMap(),
      'activity': activity,
      'description': description,
      'docId': docId,
      'collection': collection,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      uid: map['uid'] != null && map['uid'] is String
          ? map['uid'] as String
          : null,
      userData:
          map['userData'] != null && map['userData'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['userData'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      activity: map['activity'] is String ? map['activity'] as String : '',
      description: map['description'] != null && map['description'] is String
          ? map['description'] as String
          : null,
      docId: map['docId'] != null && map['docId'] is String
          ? map['docId'] as String
          : null,
      collection: map['collection'] is String
          ? map['collection'] as String
          : '',
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ActivityLogModel.fromJson(String source) =>
      ActivityLogModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ActivityLogModel(uid: $uid, userData: $userData, activity: $activity, description: $description, docId: $docId, collection: $collection, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant ActivityLogModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.userData == userData &&
        other.activity == activity &&
        other.description == description &&
        other.docId == docId &&
        other.collection == collection &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        userData.hashCode ^
        activity.hashCode ^
        description.hashCode ^
        docId.hashCode ^
        collection.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
