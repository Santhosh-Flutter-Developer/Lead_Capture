import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/models/models.dart';
import '/utils/utils.dart';

class RoleModel {
  static const String superAdminRoleName = 'Super Admin';

  final String? uid;
  final String name;
  final String lowercaseName;
  final String description;
  final List<PermissionModel> permissions;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSuperAdmin =>
      name.toLowerCase().trim() == superAdminRoleName.toLowerCase();

  RoleModel({
    this.uid,
    required this.name,
    String? lowercaseName,
    required this.description,
    this.permissions = const [],
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lowercaseName = lowercaseName ?? name.toLowerCase(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  RoleModel copyWith({
    String? uid,
    String? name,
    String? lowercaseName,
    String? description,
    List<PermissionModel>? permissions,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoleModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      lowercaseName: lowercaseName ?? this.lowercaseName,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
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
      'permissions': permissions.map((e) => e.toMap()).toList(),
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
      'permissions': permissions.map((e) => e.toMap()).toList(),
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static String _fieldFromMap(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    final decrypted = raw.decrypt;
    if (decrypted.isNotEmpty) return decrypted;
    return _isLikelyEncrypted(raw) ? '' : raw;
  }

  static bool _isLikelyEncrypted(String value) {
    if (value.isEmpty) return false;
    try {
      final decoded = base64Decode(value);
      return decoded.length >= 48;
    } catch (_) {
      return false;
    }
  }

  factory RoleModel.fromMap(String uid, Map<String, dynamic> map) {
    return RoleModel(
      uid: uid,

      name: _fieldFromMap(map['name']),

      lowercaseName: _fieldFromMap(map['lowercaseName']),

      description: _fieldFromMap(map['description']),

      permissions: (map['permissions'] is List)
          ? (map['permissions'] as List)
                .whereType<Map>()
                .map(
                  (e) => PermissionModel.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList()
          : [],

      createdBy: map['createdBy'] != null && map['createdBy'] is Map
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),

      createdAt: map['createdAt'] != null
          ? map['createdAt'] is Timestamp
                ? (map['createdAt'] as Timestamp).toDate()
                : map['createdAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
                : DateTime.now()
          : DateTime.now(),

      updatedAt: map['updatedAt'] != null
          ? map['updatedAt'] is Timestamp
                ? (map['updatedAt'] as Timestamp).toDate()
                : map['updatedAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
                : DateTime.now()
          : DateTime.now(),
    );
  }
  String toJson() => json.encode(toMap());

  factory RoleModel.fromJson(String uid, String source) =>
      RoleModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'RoleModel(uid: $uid, name: $name, lowercaseName: $lowercaseName, description: $description, permissions: $permissions, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant RoleModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.lowercaseName == lowercaseName &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        lowercaseName.hashCode ^
        description.hashCode ^
        permissions.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

class PermissionModel {
  final String page;
  bool selectAll;
  bool canCreate;
  bool canEdit;
  bool canDelete;
  bool canView;
  bool canExport;
  bool canImport;

  PermissionModel({
    required this.page,
    this.selectAll = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canView = false,
    this.canExport = false,
    this.canImport = false,
  });

  PermissionModel copyWith({
    String? page,
    bool? selectAll,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool? canView,
    bool? canExport,
    bool? canImport,
  }) {
    return PermissionModel(
      page: page ?? this.page,
      selectAll: selectAll ?? this.selectAll,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canView: canView ?? this.canView,
      canExport: canExport ?? this.canExport,
      canImport: canImport ?? this.canImport,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'page': page,
      'selectAll': selectAll,
      'canCreate': canCreate,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'canView': canView,
      'canExport': canExport,
      'canImport': canImport,
    };
  }

  factory PermissionModel.fromMap(Map<String, dynamic> map) {
    return PermissionModel(
      page: map['page']?.toString() ?? '',
      selectAll: map['selectAll'] ?? false,
      canCreate: map['canCreate'] ?? false,
      canEdit: map['canEdit'] ?? false,
      canDelete: map['canDelete'] ?? false,
      canView: map['canView'] ?? false,
      canExport: map['canExport'] ?? false,
      canImport: map['canImport'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory PermissionModel.fromJson(String source) =>
      PermissionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'PermissionModel(page: $page, selectAll: $selectAll, canCreate: $canCreate, canEdit: $canEdit, canDelete: $canDelete, canView: $canView, canExport: $canExport, canImport: $canImport)';
  }

  @override
  bool operator ==(covariant PermissionModel other) {
    if (identical(this, other)) return true;

    return other.page == page &&
        other.selectAll == selectAll &&
        other.canCreate == canCreate &&
        other.canEdit == canEdit &&
        other.canDelete == canDelete &&
        other.canView == canView &&
        other.canExport == canExport &&
        other.canImport == canImport;
  }

  @override
  int get hashCode {
    return page.hashCode ^
        selectAll.hashCode ^
        canCreate.hashCode ^
        canEdit.hashCode ^
        canDelete.hashCode ^
        canView.hashCode ^
        canExport.hashCode ^
        canImport.hashCode;
  }
}
