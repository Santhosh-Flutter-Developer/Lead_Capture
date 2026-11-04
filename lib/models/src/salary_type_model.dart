import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leadcapture/models/src/user_data_model.dart';

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

class SalaryTypeModel {
  final String? uid;
  final String name;
  final String description;
  final bool isActive;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryTypeModel({
    this.uid,
    required this.name,
    this.description = '',
    this.isActive = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  SalaryTypeModel copyWith({
    String? uid,
    String? name,
    String? description,
    bool? isActive,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryTypeModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      description: description ?? this.description,
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
      'isActive': isActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory SalaryTypeModel.fromMap(String uid, Map<String, dynamic> map) {
    return SalaryTypeModel(
      uid: uid,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] != null
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SalaryTypeModel.fromJson(String uid, String source) =>
      SalaryTypeModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SalaryTypeModel(name: $name, description: $description, isActive: $isActive)';
  }
}
