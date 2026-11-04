import 'dart:convert';
import '/models/models.dart';
import '/utils/utils.dart';

class SubDepartmentModel {
  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final String department;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubDepartmentModel({
    this.uid,
    required this.name,
    String? lowercaseName,
    required this.description,
    required this.department,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lowercaseName = lowercaseName ?? name.toLowerCase(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  SubDepartmentModel copyWith({
    String? uid,
    String? name,
    String? lowercaseName,
    String? description,
    String? department,
    String? departmentName,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubDepartmentModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lowercaseName: lowercaseName ?? this.lowercaseName,
      description: description ?? this.description,
      department: department ?? this.department,
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
      'department': department,
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
      'department': department,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SubDepartmentModel.fromMap(String uid, Map<String, dynamic> map) {
    return SubDepartmentModel(
      uid: uid,
      name: (map['name'] as String).decrypt,
      lowercaseName: (map['lowercaseName'] as String).decrypt,
      description: (map['description'] as String).decrypt,
      department: map['department'] as String,
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory SubDepartmentModel.fromJson(String uid, String source) =>
      SubDepartmentModel.fromMap(
        uid,
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'SubDepartmentModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, department: $department, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant SubDepartmentModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.department == department &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        lowercaseName.hashCode ^
        description.hashCode ^
        department.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
