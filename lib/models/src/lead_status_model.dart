import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/utils/utils.dart';
import '/models/models.dart';

class LeadStatusModel {
  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final int color;
  final int orderNumber;
  final UserDataModel createdBy;
  final bool isMoveToDeal;
  final bool isFinal;
  final DateTime createdAt;
  final DateTime updatedAt;
  LeadStatusModel({
    this.uid,
    required this.name,
    required this.description,
    required this.color,
    required this.orderNumber,
    this.isMoveToDeal = false,
    this.isFinal = false,
    required this.createdBy,
    String? lowercaseName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lowercaseName = lowercaseName ?? name.toLowerCase(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  LeadStatusModel copyWith({
    String? uid,
    String? name,
    String? lowercaseName,
    String? description,
    int? color,
    int? orderNumber,
    bool? isMoveToDeal,
    bool? isFinal,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadStatusModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lowercaseName: lowercaseName ?? this.lowercaseName,
      description: description ?? this.description,
      color: color ?? this.color,
      orderNumber: orderNumber ?? this.orderNumber,
      isMoveToDeal: isMoveToDeal ?? this.isMoveToDeal,
      isFinal: isFinal ?? this.isFinal,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name.encrypt,
      'lowercaseName': lowercaseName.encrypt,
      'description': description.encrypt,
      'color': color,
      'orderNumber': orderNumber,
      'isMoveToDeal': isMoveToDeal,
      'isFinal': isFinal,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name.encrypt,
      'lowercaseName': lowercaseName.encrypt,
      'description': description.encrypt,
      'color': color,
      'isMoveToDeal': isMoveToDeal,
      'isFinal': isFinal,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory LeadStatusModel.fromMap(String uid, Map<String, dynamic> map) {
    return LeadStatusModel(
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
      orderNumber: map['orderNumber'] != null && map['orderNumber'] is int
          ? map['orderNumber'] as int
          : 0,
      isMoveToDeal: map['isMoveToDeal'] != null && map['isMoveToDeal'] is bool
          ? map['isMoveToDeal'] as bool
          : false,
      isFinal: map['isFinal'] != null && map['isFinal'] is bool
          ? map['isFinal'] as bool
          : false,
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

  factory LeadStatusModel.fromJson(String uid, String source) =>
      LeadStatusModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'LeadStatusModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, color: $color, isMoveToDeal: $isMoveToDeal, orderNumber: $orderNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant LeadStatusModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.color == color &&
        other.orderNumber == orderNumber &&
        other.isMoveToDeal == isMoveToDeal &&
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
        orderNumber.hashCode ^
        isMoveToDeal.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
