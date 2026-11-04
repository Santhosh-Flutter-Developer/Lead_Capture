import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_model.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

class EmployeeStatusModel {
  final String? uid;
  final String name;
  final String description;
  final String color;
  final bool isActive;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeStatusModel({
    this.uid,
    required this.name,
    this.description = '',
    this.color = '#000000',
    this.isActive = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  EmployeeStatusModel copyWith({
    String? uid,
    String? name,
    String? description,
    String? color,
    bool? isActive,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeStatusModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'color': color,
      'isActive': isActive,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'isActive': isActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory EmployeeStatusModel.fromMap(String uid, Map<String, dynamic> map) {
    return EmployeeStatusModel(
      uid: uid,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      color: map['color'] ?? '#000000',
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] != null
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory EmployeeStatusModel.fromJson(String uid, String source) =>
      EmployeeStatusModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'EmployeeStatusModel(name: $name, description: $description, color: $color, isActive: $isActive)';
  }
}
