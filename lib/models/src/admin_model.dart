import 'dart:convert';
import '/models/models.dart';
import '/utils/utils.dart';

class AdminModel {
  final String? uid;
  final String name;
  final String email;
  final String password;
  final String mobileNumber;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserDataModel createdBy;
  final DateTime? lastActive;
  final List<Map<String, dynamic>>? devices; // Added devices

  // The following are shown and editable on the shared Employee/Admin edit
  // form even while "Make as Admin" is on. They must be persisted here so
  // they aren't silently discarded when a record is saved as an Admin
  // (previously these had no home on AdminModel at all).
  final String? address;
  final String? about;
  final String? skills;
  final String? employeeType;
  final String? maritalStatus;
  final bool? loginAllowed;
  final bool? receiveEmailNotifications;
  final bool? outsideOffice;

  AdminModel({
    DateTime? createdAt,
    DateTime? updatedAt,
    this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.mobileNumber,
    this.profileImageUrl,
    bool? isActive,
    required this.createdBy,
    this.lastActive,
    this.devices,
    this.address,
    this.about,
    this.skills,
    this.employeeType,
    this.maritalStatus,
    this.loginAllowed,
    this.receiveEmailNotifications,
    this.outsideOffice,
  }) : isActive = isActive ?? true,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'email': email.trim().toLowerCase(),
      'password': password.encrypt,
      'mobileNumber': mobileNumber.encrypt,
      'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'createdBy': createdBy.toMap(),
      'lastActive': lastActive?.millisecondsSinceEpoch,
      'devices': devices,
      'address': address?.encrypt,
      'about': about?.encrypt,
      'skills': skills?.encrypt,
      'employeeType': employeeType,
      'maritalStatus': maritalStatus,
      'loginAllowed': loginAllowed,
      'receiveEmailNotifications': receiveEmailNotifications,
      'outsideOffice': outsideOffice,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name.encrypt,
      'email': email.trim().toLowerCase(),
      'password': password.encrypt,
      'mobileNumber': mobileNumber.encrypt,
      'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'createdBy': createdBy.toMap(),
      'lastActive': lastActive?.millisecondsSinceEpoch,
      'devices': devices,
      'address': address?.encrypt,
      'about': about?.encrypt,
      'skills': skills?.encrypt,
      'employeeType': employeeType,
      'maritalStatus': maritalStatus,
      'loginAllowed': loginAllowed,
      'receiveEmailNotifications': receiveEmailNotifications,
      'outsideOffice': outsideOffice,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  factory AdminModel.fromJson(String uid, String source) =>
      AdminModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  AdminModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? password,
    String? mobileNumber,
    String? profileImageUrl,
    bool? isActive,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActive,
    List<Map<String, dynamic>>? devices,
    String? address,
    String? about,
    String? skills,
    String? employeeType,
    String? maritalStatus,
    bool? loginAllowed,
    bool? receiveEmailNotifications,
    bool? outsideOffice,
  }) {
    return AdminModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActive: lastActive ?? this.lastActive,
      devices: devices ?? this.devices,
      address: address ?? this.address,
      about: about ?? this.about,
      skills: skills ?? this.skills,
      employeeType: employeeType ?? this.employeeType,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      loginAllowed: loginAllowed ?? this.loginAllowed,
      receiveEmailNotifications:
          receiveEmailNotifications ?? this.receiveEmailNotifications,
      outsideOffice: outsideOffice ?? this.outsideOffice,
    );
  }

  factory AdminModel.fromMap(String uid, Map<String, dynamic> map) {
    return AdminModel(
      uid: uid,
      name: map['name'] != null && map['name'] is String
          ? (map['name'] as String).decrypt
          : '',
      email: map['email'] ?? '',
      password: map['password'] != null && map['password'] is String
          ? (map['password'] as String).decrypt
          : '',
      mobileNumber: map['mobileNumber'] != null && map['mobileNumber'] is String
          ? (map['mobileNumber'] as String).decrypt
          : '',
      profileImageUrl: map['profileImageUrl'] as String?,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : false,
      createdBy: map['createdBy'] != null && map['createdBy'] is Map
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      lastActive: map['lastActive'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActive'] as int)
          : null,
      devices: map['devices'] != null && map['devices'] is List
          ? (map['devices'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : null,
      address: map['address'] != null && map['address'] is String
          ? (map['address'] as String).decrypt
          : null,
      about: map['about'] != null && map['about'] is String
          ? (map['about'] as String).decrypt
          : null,
      skills: map['skills'] != null && map['skills'] is String
          ? (map['skills'] as String).decrypt
          : null,
      employeeType: map['employeeType'] as String?,
      maritalStatus: map['maritalStatus'] as String?,
      loginAllowed: map['loginAllowed'] is bool
          ? map['loginAllowed'] as bool
          : null,
      receiveEmailNotifications: map['receiveEmailNotifications'] is bool
          ? map['receiveEmailNotifications'] as bool
          : null,
      outsideOffice: map['outsideOffice'] is bool
          ? map['outsideOffice'] as bool
          : null,
    );
  }

  @override
  String toString() {
    return 'AdminModel(uid: $uid, name: $name, email: $email, mobileNumber: $mobileNumber, profileImageUrl: $profileImageUrl, isActive: $isActive, lastActive: $lastActive, devices: $devices, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}