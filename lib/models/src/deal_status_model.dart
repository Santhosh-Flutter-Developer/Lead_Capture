import 'dart:convert';
import '/utils/utils.dart';
import 'user_data_model.dart';

class DealStatusModel {
  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final int color;
  final int orderNumber;
  final bool isMoveToDeal;
  final bool isFinal;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  DealStatusModel({
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

  DealStatusModel copyWith({
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
    return DealStatusModel(
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

  factory DealStatusModel.fromMap(String uid, Map<String, dynamic> map) {
    return DealStatusModel(
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
      createdAt: map['createdAt'] != null && map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null && map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DealStatusModel.fromJson(String uid, String source) =>
      DealStatusModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'DealStatusModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, color: $color, isMoveToDeal: $isMoveToDeal, isFinal: $isFinal, createdBy: $createdBy, orderNumber: $orderNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant DealStatusModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.color == color &&
        other.orderNumber == orderNumber &&
        other.isMoveToDeal == isMoveToDeal &&
        other.isFinal == isFinal &&
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
        color.hashCode ^
        orderNumber.hashCode ^
        isMoveToDeal.hashCode ^
        isFinal.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
