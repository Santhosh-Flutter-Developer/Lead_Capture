import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/utils/utils.dart';
import '/models/models.dart';

class LeadPriorityModel {
  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final int color;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  LeadPriorityModel({
    this.uid,
    required this.name,
    required this.description,
    required this.color,
    required this.createdBy,
    String? lowercaseName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lowercaseName = lowercaseName ?? name.toLowerCase(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  LeadPriorityModel copyWith({
    String? uid,
    String? name,
    String? lowercaseName,
    String? description,
    int? color,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadPriorityModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lowercaseName: lowercaseName ?? this.lowercaseName,
      description: description ?? this.description,
      color: color ?? this.color,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'lowercaseName': lowercaseName.encrypt,
      'description': description.encrypt,
      'color': color,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'lowercaseName': lowercaseName.encrypt,
      'description': description.encrypt,
      'color': color,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory LeadPriorityModel.fromMap(String uid, Map<String, dynamic> map) {
    return LeadPriorityModel(
      uid: uid,
      name: map['name'] is String ? (map['name'] as String).decrypt : '',
      lowercaseName: map['lowercaseName'] is String
          ? (map['lowercaseName'] as String).decrypt
          : '',
      description: map['description'] is String
          ? (map['description'] as String).decrypt
          : '',
      color: map['color'] != null && map['color'] is int
          ? map['color'] as int
          : 0,
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory LeadPriorityModel.fromJson(String uid, String source) =>
      LeadPriorityModel.fromMap(
        uid,
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'LeadPriorityModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, color: $color, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant LeadPriorityModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.color == color &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        lowercaseName.hashCode ^
        description.hashCode ^
        color.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
