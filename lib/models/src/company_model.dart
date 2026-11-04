import 'dart:convert';
import '/models/models.dart';
import '/utils/utils.dart';

class CompanyModel {
  final String? uid;
  final String name;
  final String? branchCode;
  final String? logoUrl;
  final String? gstin;
  final String? phone;
  final String? email;
  final String? address;
  final String? country;
  final String? state;
  final String? city;
  final String? pincode;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserDataModel createdBy;
  final bool withoutLoginEnabled;
  final String notificationLanguage;
  final String? kioskUsername;

  CompanyModel({
    this.uid,
    required this.name,
    this.branchCode,
    this.logoUrl,
    this.gstin,
    this.phone,
    this.email,
    this.address,
    this.country,
    this.state,
    this.city,
    this.pincode,

    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.createdBy,
    this.withoutLoginEnabled = false,
    this.notificationLanguage = 'en',
    this.kioskUsername,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  CompanyModel copyWith({
    String? uid,
    String? name,
    String? branchCode,
    String? logoUrl,
    String? gstin,
    String? phone,
    String? email,
    String? address,
    String? country,
    String? state,
    String? city,
    String? pincode,

    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserDataModel? createdBy,
    bool? withoutLoginEnabled,
    String? notificationLanguage,
    String? kioskUsername,
  }) {
    return CompanyModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      branchCode: branchCode ?? this.branchCode,
      logoUrl: logoUrl ?? this.logoUrl,
      gstin: gstin ?? this.gstin,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,

      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      withoutLoginEnabled: withoutLoginEnabled ?? this.withoutLoginEnabled,
      notificationLanguage: notificationLanguage ?? this.notificationLanguage,
      kioskUsername: kioskUsername ?? this.kioskUsername,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'branchCode': branchCode,
      'logoUrl': logoUrl,
      'gstin': gstin,
      'phone': phone?.encrypt,
      'email': email?.encrypt,
      'address': address?.encrypt,
      'country': country,
      'state': state,
      'city': city,
      'pincode': pincode,

      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdBy': createdBy.toMap(),
      'withoutLoginEnabled': withoutLoginEnabled,
      'notificationLanguage': notificationLanguage,
      'kioskUsername': kioskUsername,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'branchCode': branchCode,
      'logoUrl': logoUrl,
      'gstin': gstin,
      'phone': phone?.encrypt,
      'email': email?.encrypt,
      'address': address?.encrypt,
      'country': country,
      'state': state,
      'city': city,
      'pincode': pincode,

      'isActive': isActive,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdBy': createdBy.toMap(),
      'withoutLoginEnabled': withoutLoginEnabled,
      'notificationLanguage': notificationLanguage,
      'kioskUsername': kioskUsername,
    };
  }

  factory CompanyModel.fromMap(String uid, Map<String, dynamic> map) {
    return CompanyModel(
      uid: uid,
      name: map['name'] != null && map['name'] is String
          ? (map['name'] as String).decrypt
          : '',
      branchCode: map['branchCode'] as String?,
      logoUrl: map['logoUrl'] as String?,
      gstin: map['gstin'] as String?,
      phone: map['phone'] != null && map['phone'] is String
          ? (map['phone'] as String).decrypt
          : null,
      email: map['email'] != null && map['email'] is String
          ? (map['email'] as String).decrypt
          : null,
      address: map['address'] != null && map['address'] is String
          ? (map['address'] as String).decrypt
          : null,
      country: map['country'] as String?,
      state: map['state'] as String?,
      city: map['city'] as String?,
      pincode: map['pincode'] as String?,

      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      createdBy: map['createdBy'] != null && map['createdBy'] is Map
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
      withoutLoginEnabled: map['withoutLoginEnabled'] is bool
          ? map['withoutLoginEnabled'] as bool
          : false,
      notificationLanguage: map['notificationLanguage'] is String
          ? map['notificationLanguage'] as String
          : 'en',
      kioskUsername: map['kioskUsername'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory CompanyModel.fromJson(String uid, String source) =>
      CompanyModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'CompanyModel(uid: $uid, name: $name, branchCode: $branchCode, logoUrl: $logoUrl, gstin: $gstin, phone: $phone, email: $email, address: $address, country: $country, state: $state, city: $city, pincode: $pincode, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, withoutLoginEnabled: $withoutLoginEnabled, notificationLanguage: $notificationLanguage, kioskUsername: $kioskUsername)';
  }

  @override
  bool operator ==(covariant CompanyModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.branchCode == branchCode &&
        other.logoUrl == logoUrl &&
        other.gstin == gstin &&
        other.phone == phone &&
        other.email == email &&
        other.address == address &&
        other.country == country &&
        other.state == state &&
        other.city == city &&
        other.pincode == pincode &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.createdBy == createdBy &&
        other.withoutLoginEnabled == withoutLoginEnabled &&
        other.notificationLanguage == notificationLanguage &&
        other.kioskUsername == kioskUsername;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        branchCode.hashCode ^
        logoUrl.hashCode ^
        gstin.hashCode ^
        phone.hashCode ^
        email.hashCode ^
        address.hashCode ^
        country.hashCode ^
        state.hashCode ^
        city.hashCode ^
        pincode.hashCode ^
        isActive.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        createdBy.hashCode ^
        withoutLoginEnabled.hashCode ^
        notificationLanguage.hashCode ^
        kioskUsername.hashCode;
  }
}
