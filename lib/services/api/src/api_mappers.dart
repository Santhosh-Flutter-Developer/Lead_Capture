import 'dart:convert';

import '/constants/constants.dart';
import '/models/models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// Tolerant JSON readers (PHP/MySQL returns ints as strings, bools as 0/1…).
class Js {
  Js._();
  static String s(dynamic v, [String d = '']) => v == null ? d : v.toString();
  static int? i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
  static double d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? def;
  static bool b(dynamic v, [bool def = false]) {
    if (v == null) return def;
    if (v is bool) return v;
    final t = v.toString().trim().toLowerCase();
    if (t == '1' || t == 'true' || t == 'yes') return true;
    if (t == '0' || t == 'false' || t == 'no' || t == '') return false;
    return def;
  }

  /// MySQL `YYYY-MM-DD[ HH:mm:ss]` or ISO. Returns null for empty / zero dates.
  static DateTime? dt(dynamic v) {
    final t = s(v).trim();
    if (t.isEmpty || t.startsWith('0000')) return null;
    return DateTime.tryParse(t.replaceFirst(' ', 'T'));
  }

  /// Server-generated timestamps written by MySQL `NOW()` (server/DB clock is
  /// UTC and the string carries no zone). Parse as UTC, show in local time.
  static DateTime? dtUtc(dynamic v) {
    final t = s(v).trim();
    if (t.isEmpty || t.startsWith('0000')) return null;
    var x = t.replaceFirst(' ', 'T');
    final hasZone = x.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(x);
    if (!hasZone) x = '${x}Z';
    return DateTime.tryParse(x)?.toLocal();
  }

  static Map<String, dynamic> m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Accepts a real list, a JSON-encoded list string (`'["a","b"]'`),
  /// a comma separated string, or null.
  static List<String> strList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    final t = v.toString().trim();
    if (t.isEmpty) return [];
    if (t.startsWith('[')) {
      try {
        final x = jsonDecode(t);
        if (x is List) return x.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> mapList(dynamic v) {
    dynamic x = v;
    if (x is String && x.trim().startsWith('[')) {
      try {
        x = jsonDecode(x);
      } catch (_) {}
    }
    if (x is! List) return [];
    return x.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String? opt(dynamic v) {
    final t = s(v).trim();
    return t.isEmpty ? null : t;
  }
}

/// uid <-> numeric id lookups. The API returns/accepts INTEGER ids for
/// role/designation/department/sub-department on employees, while the app's
/// models hold uid strings. The four master lists expose both.
class ApiLookup {
  ApiLookup._();
  static final Map<String, Map<int, String>> _uidById = {};
  static final Map<String, Map<String, int>> _idByUid = {};
  static bool _loaded = false;
  static Future<void>? _inflight;

  static const kRole = 'role';
  static const kDesignation = 'designation';
  static const kDepartment = 'department';
  static const kSubDepartment = 'sub_department';

  static void invalidate() => _loaded = false;

  static Future<void> ensure() async {
    if (_loaded) return;
    _inflight ??= _load().whenComplete(() => _inflight = null);
    await _inflight;
  }

  static Future<void> _load() async {
    final c = ApiClient.instance;
    final res = await Future.wait([
      c.post(ApiEndpoints.roles, action: 'list', body: {}),
      c.post(ApiEndpoints.masters, action: 'list', query: {'type': MasterTypes.designation}, body: {'type': MasterTypes.designation}),
      c.post(ApiEndpoints.masters, action: 'list', query: {'type': MasterTypes.department}, body: {'type': MasterTypes.department}),
      c.post(ApiEndpoints.masters, action: 'list', query: {'type': MasterTypes.subDepartment}, body: {'type': MasterTypes.subDepartment}),
    ]);
    void fill(String kind, ApiResponse r) {
      final a = <int, String>{};
      final b = <String, int>{};
      for (final row in r.dataList) {
        final m = Js.m(row);
        final id = Js.i(m['id']);
        final uid = Js.s(m['uid'] ?? m['role_uid']);
        if (id != null && uid.isNotEmpty) {
          a[id] = uid;
          b[uid] = id;
        }
      }
      _uidById[kind] = a;
      _idByUid[kind] = b;
    }

    fill(kRole, res[0]);
    fill(kDesignation, res[1]);
    fill(kDepartment, res[2]);
    fill(kSubDepartment, res[3]);
    _loaded = true;
  }

  static String uidOf(String kind, dynamic id) {
    final i = Js.i(id);
    if (i == null) return '';
    return _uidById[kind]?[i] ?? '';
  }

  static int? idOf(String kind, String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _idByUid[kind]?[uid] ?? Js.i(uid);
  }
}

/// Map PHP JSON -> existing app models. Never routes API data through
/// `.decrypt` (the PHP API stores plain text; `tryDecrypt` would blank it).
class ApiMappers {
  ApiMappers._();

  static UserDataModel createdBy(Map<String, dynamic> m) => UserDataModel(
        uid: Js.s(m['created_by']),
        name: Js.s(m['created_by_name'], 'System'),
        profilePic: ApiConfig.resolveFileUrl(Js.opt(m['created_by_photo'])),
        userType: UserType.admin,
      );

  static String? photo(dynamic v) {
    final p = Js.opt(v);
    if (p == null) return null;
    return ApiConfig.resolveFileUrl(p);
  }

  // ── Colors: server stores "#RRGGBB" (or #AARRGGBB); app models use int ARGB.
  static int colorFromServer(dynamic v, [int fallback = 0xFF2E5EAA]) {
    final t = Js.s(v).trim();
    if (t.isEmpty) return fallback;
    var h = t.startsWith('#') ? t.substring(1) : t;
    if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16) ?? int.tryParse(t) ?? fallback;
  }

  static String colorToServer(int c) =>
      '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static LeadCategoryModel leadCategory(Map<String, dynamic> m) => LeadCategoryModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static LeadSourceModel leadSource(Map<String, dynamic> m) => LeadSourceModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static PaymentModeModel paymentMode(Map<String, dynamic> m) => PaymentModeModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static LeadPriorityModel leadPriority(Map<String, dynamic> m) => LeadPriorityModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        color: colorFromServer(m['color'], 0xFFFFA000),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static LeadStatusModel leadStatus(Map<String, dynamic> m) => LeadStatusModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        color: colorFromServer(m['color']), orderNumber: Js.i(m['order_index']) ?? 0,
        isMoveToDeal: Js.b(m['is_move_to_deal']), isFinal: Js.b(m['is_final']),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static DealStatusModel dealStatus(Map<String, dynamic> m) => DealStatusModel(
        uid: Js.s(m['uid']), name: Js.s(m['name']), description: Js.s(m['description']),
        color: colorFromServer(m['color']), orderNumber: Js.i(m['order_index']) ?? 0,
        isMoveToDeal: Js.b(m['is_move_to_deal']), isFinal: Js.b(m['is_final']),
        createdBy: createdBy(m), createdAt: Js.dt(m['created_at']), updatedAt: Js.dt(m['updated_at']));

  static DesignationModel designation(Map<String, dynamic> m) => DesignationModel(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        description: Js.s(m['description']),
        createdBy: createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static DepartmentModel department(Map<String, dynamic> m) => DepartmentModel(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        description: Js.s(m['description']),
        createdBy: createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static SubDepartmentModel subDepartment(Map<String, dynamic> m) => SubDepartmentModel(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        description: Js.s(m['description']),
        department: Js.s(m['department_uid']),
        createdBy: createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static PermissionModel permission(Map<String, dynamic> m, {String? page}) {
    final v = Js.b(m['can_view']);
    final c = Js.b(m['can_create']);
    final e = Js.b(m['can_edit']);
    final d = Js.b(m['can_delete']);
    final x = Js.b(m['can_export']);
    final im = Js.b(m['can_import']);
    return PermissionModel(
      page: page ?? Js.s(m['page']),
      selectAll: v && c && e && d && x && im,
      canView: v,
      canCreate: c,
      canEdit: e,
      canDelete: d,
      canExport: x,
      canImport: im,
    );
  }

  /// Handles both shapes: roles.php `permissions: [ {page,...} ]` and the
  /// login response `permissions: { "Leads": {...} }` (or `{all: true}`).
  static List<PermissionModel> permissions(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => permission(Map<String, dynamic>.from(e))).toList();
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (Js.b(map['all'])) return AppStrings.permissionsTrueMap;
      return map.entries
          .where((e) => e.value is Map)
          .map((e) => permission(Map<String, dynamic>.from(e.value as Map), page: e.key))
          .toList();
    }
    return [];
  }

  static RoleModel role(Map<String, dynamic> m) => RoleModel(
        uid: Js.s(m['uid'] ?? m['role_uid']),
        name: Js.s(m['name']),
        description: Js.s(m['description']),
        permissions: permissions(m['permissions']),
        createdBy: createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static List<Map<String, dynamic>> permissionsBody(List<PermissionModel> list) => list
      .map((p) => {
            'page': p.page,
            'can_view': p.canView ? 1 : 0,
            'can_create': p.canCreate ? 1 : 0,
            'can_edit': p.canEdit ? 1 : 0,
            'can_delete': p.canDelete ? 1 : 0,
            'can_export': p.canExport ? 1 : 0,
            'can_import': p.canImport ? 1 : 0,
          })
      .toList();

  // ───────────────────────── users ─────────────────────────

  static bool isAdminRow(Map<String, dynamic> m) => Js.s(m['user_type']).toLowerCase() == 'admin';

  /// Requires `await ApiLookup.ensure()` beforehand.
  static EmployeeModel employee(Map<String, dynamic> m) {
    final dept = ApiLookup.uidOf(ApiLookup.kDepartment, m['department_id']);
    final sub = ApiLookup.uidOf(ApiLookup.kSubDepartment, m['sub_department_id']);
    final active = Js.b(m['is_active'], true);
    return EmployeeModel(
      uid: Js.s(m['uid']),
      employeeId: Js.s(m['employee_id']),
      name: Js.s(m['name']),
      email: Js.s(m['email']),
      password: '',
      designation: ApiLookup.uidOf(ApiLookup.kDesignation, m['designation_id']),
      department: dept.isEmpty ? <String>[] : [dept],
      subDepartment: sub.isEmpty ? null : sub,
      mobileNumber: Js.s(m['mobile_number']),
      profileImageUrl: photo(m['profile_image_url']),
      gender: Js.s(m['gender']),
      dateOfJoining: Js.dt(m['date_of_joining']) ?? DateTime.now(),
      dateOfBirth: Js.dt(m['date_of_birth']),
      role: ApiLookup.uidOf(ApiLookup.kRole, m['role_id']),
      address: Js.s(m['address']),
      about: Js.s(m['about']),
      loginAllowed: Js.b(m['login_allowed'], true),
      receiveEmailNotifications: Js.b(m['receive_email_notifications']),
      skills: Js.s(m['skills']),
      employeeType: Js.opt(m['employee_type']),
      reportingTo: Js.strList(m['reporting_to']),
      maritalStatus: Js.s(m['marital_status']),
      isActive: active,
      lastActive: Js.dt(m['last_active']),
      isInitialPasswordChanged: Js.b(m['is_initial_password_changed'], true),
      outsideOffice: Js.b(m['outside_office']),
      createdBy: createdBy(m),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }

  static AdminModel admin(Map<String, dynamic> m) => AdminModel(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        email: Js.s(m['email']),
        password: '',
        mobileNumber: Js.s(m['mobile_number']),
        profileImageUrl: photo(m['profile_image_url']),
        isActive: Js.b(m['is_active'], true),
        createdBy: createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
        lastActive: Js.dt(m['last_active']),
        address: Js.opt(m['address']),
        about: Js.opt(m['about']),
        skills: Js.opt(m['skills']),
        employeeType: Js.opt(m['employee_type']),
        maritalStatus: Js.opt(m['marital_status']),
        loginAllowed: Js.b(m['login_allowed'], true),
        receiveEmailNotifications: Js.b(m['receive_email_notifications']),
        outsideOffice: Js.b(m['outside_office']),
      );


  /// employees.php `update` OVERWRITES every column, so partial updates must
  /// resend the existing row. Builds a full body from a raw user row, with
  /// optional overrides applied on top.
  static Map<String, dynamic> rowToUpdateBody(
    Map<String, dynamic> row, {
    String? profileImage,
    Map<String, dynamic> overrides = const {},
  }) {
    String? d(dynamic v) {
      final t = Js.dt(v);
      if (t == null) return null;
      return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    }

    final body = <String, dynamic>{
      'employee_id': Js.s(row['employee_id']),
      'name': Js.s(row['name']),
      'email': Js.s(row['email']),
      'mobile_number': Js.s(row['mobile_number']),
      'gender': Js.s(row['gender'], 'Male'),
      'date_of_joining': d(row['date_of_joining']),
      'date_of_birth': d(row['date_of_birth']),
      'role_id': Js.i(row['role_id']),
      'designation_id': Js.i(row['designation_id']),
      'department_id': Js.i(row['department_id']),
      'sub_department_id': Js.i(row['sub_department_id']),
      'skills': Js.s(row['skills']),
      'about': Js.s(row['about']),
      'address': Js.s(row['address']),
      'employee_type': Js.s(row['employee_type'], 'Full Time'),
      'marital_status': Js.s(row['marital_status'], 'Single'),
      'login_allowed': Js.b(row['login_allowed'], true) ? 1 : 0,
      'receive_email_notifications': Js.b(row['receive_email_notifications']) ? 1 : 0,
      'outside_office': Js.b(row['outside_office']) ? 1 : 0,
    };
    final img = profileImage ?? Js.opt(row['profile_image_url']);
    if (img != null) body['profile_image_url'] = ApiConfig.toRelativePath(img);
    body.addAll(overrides);
    return body;
  }

  /// Request body for employees.php create/update from an [EmployeeModel].
  /// `password` is only included when non-empty (blank keeps the old one).
  static Map<String, dynamic> employeeBody(EmployeeModel e, {bool makeAdmin = false}) {
    String? d(DateTime? t) => t == null
        ? null
        : '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final dept = (e.department != null && e.department!.isNotEmpty) ? e.department!.first : null;
    return {
      'employee_id': e.employeeId,
      'name': e.name,
      'email': e.email.trim().toLowerCase(),
      if (e.password.isNotEmpty) 'password': e.password,
      'mobile_number': e.mobileNumber,
      'gender': e.gender.isEmpty ? 'Male' : e.gender,
      'date_of_joining': d(e.dateOfJoining),
      'date_of_birth': d(e.dateOfBirth),
      'role_id': ApiLookup.idOf(ApiLookup.kRole, e.role),
      'designation_id': ApiLookup.idOf(ApiLookup.kDesignation, e.designation),
      'department_id': ApiLookup.idOf(ApiLookup.kDepartment, dept),
      'sub_department_id': ApiLookup.idOf(ApiLookup.kSubDepartment, e.subDepartment),
      'reporting_to': e.reportingTo ?? <String>[],
      'skills': e.skills,
      'about': e.about,
      'address': e.address,
      'employee_type': e.employeeType ?? 'Full Time',
      'marital_status': e.maritalStatus.isEmpty ? 'Single' : e.maritalStatus,
      'make_as_admin': makeAdmin ? 1 : 0,
      'login_allowed': e.loginAllowed ? 1 : 0,
      'receive_email_notifications': e.receiveEmailNotifications ? 1 : 0,
      'outside_office': e.outsideOffice ? 1 : 0,
      if (e.profileImageUrl != null && e.profileImageUrl!.isNotEmpty)
        'profile_image_url': ApiConfig.toRelativePath(e.profileImageUrl),
    };
  }
}