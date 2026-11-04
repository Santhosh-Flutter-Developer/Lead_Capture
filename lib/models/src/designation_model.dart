import 'dart:convert';
import '/utils/utils.dart';
import '/models/models.dart';

class DesignationModel {
  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  DesignationModel({
    this.uid,
    required this.name,
    String? lowercaseName,
    required this.description,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lowercaseName = lowercaseName ?? name.toLowerCase(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  DesignationModel copyWith({
    String? uid,
    String? name,
    String? lowercaseName,
    String? description,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DesignationModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lowercaseName: lowercaseName ?? this.lowercaseName,
      description: description ?? this.description,
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
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory DesignationModel.fromMap(String uid, Map<String, dynamic> map) {
    return DesignationModel(
      uid: uid,
      name: map['name'] != null && map['name'] is String
          ? (map['name'] as String).decrypt
          : '',
      lowercaseName:
          map['lowercaseName'] != null && map['lowercaseName'] is String
          ? (map['lowercaseName'] as String).decrypt
          : '',
      description: map['description'] != null && map['description'] is String
          ? (map['description'] as String).decrypt
          : '',
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: map['createdAt'] != null && map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null && map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DesignationModel.fromJson(String uid, String source) =>
      DesignationModel.fromMap(
        uid,
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'DesignationModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant DesignationModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        lowercaseName.hashCode ^
        description.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
