import 'dart:convert';
import '/utils/utils.dart';
import 'user_data_model.dart';

class BankModel {
  final String? uid;
  final String shortCode;
  final String lowercaseShortCode;
  final String bankName;
  final String lowercaseBankName;
  final String ifscCode;
  final String place;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankModel({
    this.uid,
    required this.shortCode,
    String? lowercaseShortCode,
    required this.bankName,
    String? lowercaseBankName,
    required this.ifscCode,
    required this.place,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : lowercaseShortCode = lowercaseShortCode ?? shortCode.toLowerCase(),
        lowercaseBankName = lowercaseBankName ?? bankName.toLowerCase(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  BankModel copyWith({
    String? uid,
    String? shortCode,
    String? lowercaseShortCode,
    String? bankName,
    String? lowercaseBankName,
    String? ifscCode,
    String? place,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankModel(
      uid: uid ?? this.uid,
      shortCode: shortCode ?? this.shortCode,
      lowercaseShortCode: lowercaseShortCode ?? this.lowercaseShortCode,
      bankName: bankName ?? this.bankName,
      lowercaseBankName: lowercaseBankName ?? this.lowercaseBankName,
      ifscCode: ifscCode ?? this.ifscCode,
      place: place ?? this.place,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shortCode': shortCode.encrypt,
      'lowercaseShortCode': lowercaseShortCode.encrypt,
      'bankName': bankName.encrypt,
      'lowercaseBankName': lowercaseBankName.encrypt,
      'ifscCode': ifscCode.encrypt,
      'place': place.encrypt,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'shortCode': shortCode.encrypt,
      'lowercaseShortCode': lowercaseShortCode.encrypt,
      'bankName': bankName.encrypt,
      'lowercaseBankName': lowercaseBankName.encrypt,
      'ifscCode': ifscCode.encrypt,
      'place': place.encrypt,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BankModel.fromMap(String uid, Map<String, dynamic> map) {
    return BankModel(
      uid: uid,
      shortCode: map['shortCode'] != null && map['shortCode'] is String
          ? (map['shortCode'] as String).decrypt
          : '',
      lowercaseShortCode:
          map['lowercaseShortCode'] != null &&
                  map['lowercaseShortCode'] is String
              ? (map['lowercaseShortCode'] as String).decrypt
              : '',
      bankName: map['bankName'] != null && map['bankName'] is String
          ? (map['bankName'] as String).decrypt
          : '',
      lowercaseBankName:
          map['lowercaseBankName'] != null &&
                  map['lowercaseBankName'] is String
              ? (map['lowercaseBankName'] as String).decrypt
              : '',
      ifscCode: map['ifscCode'] != null && map['ifscCode'] is String
          ? (map['ifscCode'] as String).decrypt
          : '',
      place: map['place'] != null && map['place'] is String
          ? (map['place'] as String).decrypt
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

  factory BankModel.fromJson(String uid, String source) =>
      BankModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'BankModel(uid: $uid, shortCode: $shortCode, bankName: $bankName, ifscCode: $ifscCode, place: $place, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
