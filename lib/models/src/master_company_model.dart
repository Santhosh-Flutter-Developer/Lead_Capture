import 'dart:convert';
import '/models/models.dart';

/// A Master Company: company details plus its primary contact, kept in its
/// own collection (`masterCompanies`).
class MasterCompanyModel {
  final String? uid;
  final String companyName;
  final String? logoUrl;
  final String? gstVatNumber;
  final String contactName;
  final String mobileNumber;
  final String? email;
  final String? companyAddress;
  final RegionModel? country;
  final StateModel? state;
  final DistrictModel? district;
  final CityModel? city;
  final String? postalCode;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MasterCompanyModel({
    this.uid,
    required this.companyName,
    this.logoUrl,
    this.gstVatNumber,
    required this.contactName,
    required this.mobileNumber,
    this.email,
    this.companyAddress,
    this.country,
    this.state,
    this.district,
    this.city,
    this.postalCode,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  MasterCompanyModel copyWith({
    String? uid,
    String? companyName,
    String? logoUrl,
    bool clearLogo = false,
    String? gstVatNumber,
    String? contactName,
    String? mobileNumber,
    String? email,
    String? companyAddress,
    RegionModel? country,
    StateModel? state,
    DistrictModel? district,
    CityModel? city,
    String? postalCode,
    // When true, country/state/district/city are taken exactly as passed
    // (including null) so a cleared dropdown actually clears the value.
    bool clearLocation = false,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterCompanyModel(
      uid: uid ?? this.uid,
      companyName: companyName ?? this.companyName,
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      gstVatNumber: gstVatNumber ?? this.gstVatNumber,
      contactName: contactName ?? this.contactName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      companyAddress: companyAddress ?? this.companyAddress,
      country: clearLocation ? country : (country ?? this.country),
      state: clearLocation ? state : (state ?? this.state),
      district: clearLocation ? district : (district ?? this.district),
      city: clearLocation ? city : (city ?? this.city),
      postalCode: postalCode ?? this.postalCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'companyName': companyName,
    'logoUrl': logoUrl,
    'gstVatNumber': gstVatNumber,
    'contactName': contactName,
    'mobileNumber': mobileNumber,
    'email': email,
    'companyAddress': companyAddress,
    'country': country?.toMap(),
    'state': state?.toMap(),
    'district': district?.toMap(),
    'city': city?.toMap(),
    'postalCode': postalCode,
    'createdBy': createdBy.toMap(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory MasterCompanyModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime ts(dynamic v) => v is int
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : DateTime.now();
    return MasterCompanyModel(
      uid: uid,
      companyName: (map['companyName'] ?? '') as String,
      logoUrl: map['logoUrl'] as String?,
      gstVatNumber: map['gstVatNumber'] as String?,
      contactName: (map['contactName'] ?? '') as String,
      mobileNumber: (map['mobileNumber'] ?? '') as String,
      email: map['email'] as String?,
      companyAddress: map['companyAddress'] as String?,
      country: map['country'] is Map<String, dynamic>
          ? RegionModel.fromRefMap(map['country'] as Map<String, dynamic>)
          : null,
      state: map['state'] is Map<String, dynamic>
          ? StateModel.fromMap(map['state'] as Map<String, dynamic>)
          : null,
      district: map['district'] is Map<String, dynamic>
          ? DistrictModel.fromMap(map['district'] as Map<String, dynamic>)
          : null,
      city: map['city'] is Map<String, dynamic>
          ? CityModel.fromMap(map['city'] as Map<String, dynamic>)
          : null,
      postalCode: map['postalCode'] as String?,
      createdBy: map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: ts(map['createdAt']),
      updatedAt: ts(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());
}