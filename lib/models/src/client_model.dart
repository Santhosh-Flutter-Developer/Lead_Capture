import 'dart:convert';
import '/models/models.dart';

class ClientModel {
  final String? uid;
  final String? salutation;
  final String? clientName;
  final String? email;
  final String? password;
  final String? mobileNumber;
  final String? gender;
  final String? changeLanguage;
  final String? profilePictureUrl;
  final bool? loginAllowed;
  final bool? receiveEmailNotifications;
  final String? companyName;
  final String? officialWebsite;
  final String? gstVatNumber;
  final String? officePhoneNo;
  final RegionModel? country;
  final StateModel? state;
  final DistrictModel? district;
  final CityModel? city;
  final String? postalCode;
  final UserDataModel createdBy;
  final String? companyAddress;
  final String? shippingAddress;
  final String? notes;
  final String? companyLogoUrl;
  final bool isActive;
  final bool isCompany;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Company name, falling back to the contact name for legacy records.
  String get displayName {
    final company = (companyName ?? '').trim();
    if (company.isNotEmpty) return company;
    return (clientName ?? '').trim();
  }

  ClientModel({
    this.uid,
    this.salutation,
    this.clientName,
    this.email,
    this.password,
    this.mobileNumber,
    this.gender,
    this.changeLanguage,
    this.profilePictureUrl,
    this.loginAllowed,
    this.receiveEmailNotifications,
    this.companyName,
    this.officialWebsite,
    this.gstVatNumber,
    this.officePhoneNo,
    this.country,
    this.state,
    this.district,
    this.city,
    this.postalCode,
    required this.createdBy,
    this.companyAddress,
    this.shippingAddress,
    this.notes,
    this.companyLogoUrl,
    this.isActive = true,
    required this.isCompany,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ClientModel copyWith({
    String? uid,
    String? salutation,
    String? clientName,
    String? email,
    String? password,
    String? mobileNumber,
    String? gender,
    String? changeLanguage,
    String? profilePictureUrl,
    bool? loginAllowed,
    bool? receiveEmailNotifications,
    String? companyName,
    String? officialWebsite,
    String? gstVatNumber,
    String? officePhoneNo,
    RegionModel? country,
    StateModel? state,
    DistrictModel? district,
    CityModel? city,
    String? postalCode,
    UserDataModel? createdBy,
    String? companyAddress,
    String? shippingAddress,
    String? notes,
    String? companyLogoUrl,
    bool? isActive,
    bool? isCompany,
    DateTime? createdAt,
    DateTime? updatedAt,
    // When true, country/state/district/city are taken exactly as passed
    // (including null) so a cleared dropdown actually clears the value.
    bool clearLocation = false,
  }) {
    return ClientModel(
      uid: uid ?? this.uid,
      salutation: salutation ?? this.salutation,
      clientName: clientName ?? this.clientName,
      email: email ?? this.email,
      password: password ?? this.password,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      gender: gender ?? this.gender,
      changeLanguage: changeLanguage ?? this.changeLanguage,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      loginAllowed: loginAllowed ?? this.loginAllowed,
      receiveEmailNotifications:
          receiveEmailNotifications ?? this.receiveEmailNotifications,
      companyName: companyName ?? this.companyName,
      officialWebsite: officialWebsite ?? this.officialWebsite,
      gstVatNumber: gstVatNumber ?? this.gstVatNumber,
      officePhoneNo: officePhoneNo ?? this.officePhoneNo,
      country: clearLocation ? country : (country ?? this.country),
      state: clearLocation ? state : (state ?? this.state),
      district: clearLocation ? district : (district ?? this.district),
      city: clearLocation ? city : (city ?? this.city),
      postalCode: postalCode ?? this.postalCode,
      createdBy: createdBy ?? this.createdBy,
      companyAddress: companyAddress ?? this.companyAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      notes: notes ?? this.notes,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      isActive: isActive ?? this.isActive,
      isCompany: isCompany ?? this.isCompany,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'salutation': salutation,
      'clientName': clientName,
      'email': email,
      'password': password,
      'mobileNumber': mobileNumber,
      'gender': gender,
      'changeLanguage': changeLanguage,
      'profilePictureUrl': profilePictureUrl,
      'loginAllowed': loginAllowed,
      'receiveEmailNotifications': receiveEmailNotifications,
      'companyName': companyName,
      'officialWebsite': officialWebsite,
      'gstVatNumber': gstVatNumber,
      'officePhoneNo': officePhoneNo,
      'country': country?.toMap(),
      'state': state?.toMap(),
      'district': district?.toMap(),
      'city': city?.toMap(),
      'postalCode': postalCode,
      'createdBy': createdBy.toMap(),
      'companyAddress': companyAddress,
      'shippingAddress': shippingAddress,
      'notes': notes,
      'companyLogoUrl': companyLogoUrl,
      'isActive': isActive,
      'isCompany': isCompany,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'uid': uid,
      'salutation': salutation,
      'clientName': clientName,
      'email': email,
      'password': password,
      'mobileNumber': mobileNumber,
      'gender': gender,
      'changeLanguage': changeLanguage,
      'profilePictureUrl': profilePictureUrl,
      'loginAllowed': loginAllowed,
      'receiveEmailNotifications': receiveEmailNotifications,
      'companyName': companyName,
      'officialWebsite': officialWebsite,
      'gstVatNumber': gstVatNumber,
      'officePhoneNo': officePhoneNo,
      'country': country?.toMap(),
      'state': state?.toMap(),
      'district': district?.toMap(),
      'city': city?.toMap(),
      'postalCode': postalCode,
      'createdBy': createdBy.toMap(),
      'companyAddress': companyAddress,
      'shippingAddress': shippingAddress,
      'notes': notes,
      'companyLogoUrl': companyLogoUrl,
      'isActive': isActive,
      'isCompany': isCompany,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ClientModel.fromMap(String uid, Map<String, dynamic> map) {
    return ClientModel(
      uid: uid,
      salutation: map['salutation'] != null && map['salutation'] is String
          ? map['salutation'] as String
          : null,
      clientName: map['clientName'] is String
          ? map['clientName'] as String
          : '',
      email: map['email'] is String ? map['email'] as String : '',
      password: map['password'] is String ? map['password'] as String : '',
      mobileNumber: map['mobileNumber'] is String
          ? map['mobileNumber'] as String
          : '',
      gender: map['gender'] != null && map['gender'] is String
          ? map['gender'] as String
          : null,
      changeLanguage:
          map['changeLanguage'] != null && map['changeLanguage'] is String
          ? map['changeLanguage'] as String
          : null,
      profilePictureUrl:
          map['profilePictureUrl'] != null && map['profilePictureUrl'] is String
          ? map['profilePictureUrl'] as String
          : null,
      loginAllowed: map['loginAllowed'] is bool
          ? map['loginAllowed'] as bool
          : false,
      receiveEmailNotifications: map['receiveEmailNotifications'] is bool
          ? map['receiveEmailNotifications'] as bool
          : false,
      companyName: map['companyName'] is String
          ? map['companyName'] as String
          : '',
      officialWebsite:
          map['officialWebsite'] != null && map['officialWebsite'] is String
          ? map['officialWebsite'] as String
          : null,
      gstVatNumber: map['gstVatNumber'] != null && map['gstVatNumber'] is String
          ? map['gstVatNumber'] as String
          : null,
      officePhoneNo:
          map['officePhoneNo'] != null && map['officePhoneNo'] is String
          ? map['officePhoneNo'] as String
          : null,
      country: map['country'] != null && map['country'] is Map<String, dynamic>
          ? RegionModel.fromRefMap(map['country'] as Map<String, dynamic>)
          : null,
      state: map['state'] != null && map['state'] is Map<String, dynamic>
          ? StateModel.fromMap(map['state'] as Map<String, dynamic>)
          : null,
      district:
          map['district'] != null && map['district'] is Map<String, dynamic>
          ? DistrictModel.fromMap(map['district'] as Map<String, dynamic>)
          : null,
      city: map['city'] != null && map['city'] is Map<String, dynamic>
          ? CityModel.fromMap(map['city'] as Map<String, dynamic>)
          : null,
      postalCode: map['postalCode'] != null && map['postalCode'] is String
          ? map['postalCode'] as String
          : null,
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      companyAddress:
          map['companyAddress'] != null && map['companyAddress'] is String
          ? map['companyAddress'] as String
          : null,
      shippingAddress:
          map['shippingAddress'] != null && map['shippingAddress'] is String
          ? map['shippingAddress'] as String
          : null,
      notes: map['notes'] != null && map['notes'] is String
          ? map['notes'] as String
          : null,
      companyLogoUrl:
          map['companyLogoUrl'] != null && map['companyLogoUrl'] is String
          ? map['companyLogoUrl'] as String
          : null,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : false,
      isCompany: map['isCompany'] is bool ? map['isCompany'] as bool : false,
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ClientModel.fromJson(String uid, String source) =>
      ClientModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ClientModel(uid: $uid, salutation: $salutation, clientName: $clientName, email: $email, password: $password, mobileNumber: $mobileNumber, gender: $gender, changeLanguage: $changeLanguage, profilePictureUrl: $profilePictureUrl, loginAllowed: $loginAllowed, receiveEmailNotifications: $receiveEmailNotifications, companyName: $companyName, officialWebsite: $officialWebsite, gstVatNumber: $gstVatNumber, officePhoneNo: $officePhoneNo, country: $country, state: $state, district: $district, city: $city, postalCode: $postalCode, createdBy: $createdBy, companyAddress: $companyAddress, shippingAddress: $shippingAddress, notes: $notes, companyLogoUrl: $companyLogoUrl, isActive: $isActive, isCompany: $isCompany, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant ClientModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.salutation == salutation &&
        other.clientName == clientName &&
        other.email == email &&
        other.password == password &&
        other.mobileNumber == mobileNumber &&
        other.gender == gender &&
        other.changeLanguage == changeLanguage &&
        other.profilePictureUrl == profilePictureUrl &&
        other.loginAllowed == loginAllowed &&
        other.receiveEmailNotifications == receiveEmailNotifications &&
        other.companyName == companyName &&
        other.officialWebsite == officialWebsite &&
        other.gstVatNumber == gstVatNumber &&
        other.officePhoneNo == officePhoneNo &&
        other.country == country &&
        other.state == state &&
        other.district == district &&
        other.city == city &&
        other.postalCode == postalCode &&
        other.createdBy == createdBy &&
        other.companyAddress == companyAddress &&
        other.shippingAddress == shippingAddress &&
        other.notes == notes &&
        other.companyLogoUrl == companyLogoUrl &&
        other.isActive == isActive &&
        other.isCompany == isCompany &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        salutation.hashCode ^
        clientName.hashCode ^
        email.hashCode ^
        password.hashCode ^
        mobileNumber.hashCode ^
        gender.hashCode ^
        changeLanguage.hashCode ^
        profilePictureUrl.hashCode ^
        loginAllowed.hashCode ^
        receiveEmailNotifications.hashCode ^
        companyName.hashCode ^
        officialWebsite.hashCode ^
        gstVatNumber.hashCode ^
        officePhoneNo.hashCode ^
        country.hashCode ^
        state.hashCode ^
        district.hashCode ^
        city.hashCode ^
        postalCode.hashCode ^
        createdBy.hashCode ^
        companyAddress.hashCode ^
        shippingAddress.hashCode ^
        notes.hashCode ^
        companyLogoUrl.hashCode ^
        isActive.hashCode ^
        isCompany.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}