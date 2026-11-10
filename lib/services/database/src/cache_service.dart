import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '/services/services.dart';
import '/models/models.dart';

// --- TASK NAME ---
const String syncTaskName = "periodicSyncTask";

// --- CONFIGURATION HELPER ---
class _BoxConfig {
  final String boxName;
  final String collectionName;
  const _BoxConfig(this.boxName, this.collectionName);
}

class CacheService {
  // --- CONFIGURATION MAP ---
  // Maps specific keys to their Hive box (filled from the PHP API services)
  static const Map<String, _BoxConfig> _config = {
    'employee': _BoxConfig('employees', 'employees'),
    'admin': _BoxConfig('admins', 'admins'),
    'department': _BoxConfig('departments', 'departments'),
    'designation': _BoxConfig('designations', 'designations'),
    'role': _BoxConfig('roles', 'roles'),
    'subDepartment': _BoxConfig('subDepartments', 'subDepartments'),
    'leadCategory': _BoxConfig('leadCategory', 'leadCategory'),
    'leadStatus': _BoxConfig('leadStatus', 'leadStatus'),
    'leadPriority': _BoxConfig('leadPriority', 'leadPriority'),
    'dealStatus': _BoxConfig('dealStatus', 'dealStatus'),
    'project': _BoxConfig('projects', 'projects'),
    'task': _BoxConfig('tasks', 'tasks'),
  };

  static const String _metaBox = 'meta';

  // --- STATE ---
  bool _isInitialized = false;
  Timer? _periodicTimer;

  // Prevent duplicate network calls for the same missing ID
  static final Set<String> _pendingFetches = {};

  static dynamic _normalizeCacheValue(dynamic value) {
    return normalizeFromCache(value);
  }

  /// Recursively converts all Map keys to String and nested Maps/Lists too.
  /// Use this whenever reading raw data from a Hive box before passing to fromMap.
  static Map<String, dynamic> normalizeFromCache(dynamic value) {
    if (value is Map) {
      return value.map((key, entry) {
        final normalized = entry is Map
            ? normalizeFromCache(entry)
            : entry is List
            ? _normalizeList(entry)
            : entry;
        return MapEntry(key.toString(), normalized);
      });
    }
    return {};
  }

  static List<dynamic> _normalizeList(List list) {
    return list.map((e) => e is Map ? normalizeFromCache(e) : e).toList();
  }

  // ---------------- INITIALIZATION ----------------
  Future<void> init() async {
    if (_isInitialized) return;

    await _initHive();
    await _openBoxes();
    await _initSyncScheduler();

    _isInitialized = true;
    debugPrint("CacheService initialized");
  }

  /// On desktop, `Hive.initFlutter()` uses the Documents folder, which on
  /// Windows is often redirected to OneDrive. OneDrive locks the `.lock`
  /// files Hive creates (errno 32/33), so no box can open. Use the local,
  /// non-synced app-support folder (AppData) on desktop instead.
  Future<void> _initHive() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Hive.initFlutter('lead_capture_crm');
      return;
    }
    final dir = await getApplicationSupportDirectory();
    Hive.init('${dir.path}/lead_capture_crm');
  }

  Future<void> _openBoxes() async {
    for (var conf in _config.values) {
      await _openBoxSafely<Map<dynamic, dynamic>>(conf.boxName);
    }
    await _openBoxSafely<dynamic>(_metaBox);
  }

  /// Opens a box, retrying briefly if the file is locked by another process
  /// (e.g. a previous instance that is still shutting down).
  Future<void> _openBoxSafely<T>(String name) async {
    if (Hive.isBoxOpen(name)) return;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await Hive.openBox<T>(name);
        return;
      } catch (e, st) {
        debugPrint("Failed to open box $name (attempt $attempt): $e");
        if (attempt == 3) {
          await ErrorService.recordError(e, st);
        } else {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
  }

  // ---------------- SCHEDULER ----------------
  Future<void> _initSyncScheduler() async {
    try {
      _periodicTimer?.cancel();
      // Sync all data every 6 hours as a fallback
      _periodicTimer = Timer.periodic(const Duration(hours: 6), (_) async {
        debugPrint("Timer-based full sync triggered...");
        await syncAllCollections();
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // ---------------- GENERIC GETTER ----------------
  /// Checks cache. If missing, triggers a background fetch for ONLY that item.
  static T? _getEntity<T>({
    required String uid,
    required String configKey,
    required T Function(String id, Map<String, dynamic> data) fromMap,
  }) {
    try {
      final conf = _config[configKey]!;
      final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);
      final data = box.get(uid);

      if (data != null) {
        // Found in cache
        final normalized = _normalizeCacheValue(data);
        return fromMap(uid, Map<String, dynamic>.from(normalized as Map));
      }

      // Not found: refresh this list from the API
      _fetchSingleDocument(uid, conf);

      return null;
    } catch (e, st) {
      debugPrint("Error getting $configKey ($uid): $e, $st");
      return null;
    }
  }

  /// A single record cannot be fetched by uid from the API for every entity,
  /// so a cache miss refreshes that entity's whole list (debounced).
  static Future<void> _fetchSingleDocument(String uid, _BoxConfig conf) async {
    if (uid.isEmpty) return;
    final fetchKey = conf.boxName;
    if (_pendingFetches.contains(fetchKey)) return;
    _pendingFetches.add(fetchKey);
    try {
      final key = _config.entries.firstWhere((e) => e.value == conf).key;
      await syncSelectedCollections([key]);
    } catch (e) {
      debugPrint("Cache refresh failed: $e");
    } finally {
      // Avoid hammering the API when the uid really does not exist.
      Future.delayed(const Duration(seconds: 20), () => _pendingFetches.remove(fetchKey));
    }
  }

  /// Loads one entity list through the migrated API services and returns
  /// {uid: model.toMap()} (the exact shape the models' fromMap reads).
  static Future<Map<String, Map<String, dynamic>>> _load(String key) async {
    Map<String, Map<String, dynamic>> out(
      Iterable<dynamic> items,
      String? Function(dynamic) uid,
      Map<String, dynamic> Function(dynamic) map,
    ) {
      final m = <String, Map<String, dynamic>>{};
      for (final i in items) {
        final id = uid(i);
        if (id == null || id.isEmpty) continue;
        m[id] = map(i);
      }
      return m;
    }

    switch (key) {
      case 'employee':
        return out(await EmployeeService.getAllEmployees(), (e) => e.uid, (e) => e.toMap());
      case 'admin':
        return out(await AdminService.getAllAdmins(), (e) => e.uid, (e) => e.toMap());
      case 'department':
        return out(await DepartmentService.getAllDepartments(), (e) => e.uid, (e) => e.toMap());
      case 'designation':
        return out(await DesignationService.getAllDesignations(), (e) => e.uid, (e) => e.toMap());
      case 'role':
        return out(await RoleService.getAllRoles(), (e) => e.uid, (e) => e.toMap());
      case 'subDepartment':
        return out(await SubDepartmentService.getAllSubDepartments(), (e) => e.uid, (e) => e.toMap());
      case 'leadCategory':
        return out(await LeadCategoryService.getAllLeadCategories(), (e) => e.uid, (e) => e.toMap());
      case 'leadStatus':
        return out(await LeadStatusService.getAllLeadStatus(), (e) => e.uid, (e) => e.toMap());
      case 'leadPriority':
        return out(await LeadPriorityService.getAllLeadPriority(), (e) => e.uid, (e) => e.toMap());
      case 'dealStatus':
        return out(await DealStatusService.getAllDealStatus(), (e) => e.uid, (e) => e.toMap());
      case 'project':
        return out(await ProjectService.getAllProjects(), (e) => e.uid, (e) => e.toMap());
      case 'task':
        return out(await TaskService.getAllTasks(), (e) => e.uid, (e) => e.toMap());
    }
    return {};
  }

  // ---------------- PUBLIC ACCESSORS ----------------

  static EmployeeModel? employeeByUid(String uid) {
    return _getEntity<EmployeeModel>(
      uid: uid,
      configKey: 'employee',
      fromMap: EmployeeModel.fromMap,
    );
  }

  static AdminModel? adminByUid(String uid) {
    return _getEntity<AdminModel>(
      uid: uid,
      configKey: 'admin',
      fromMap: AdminModel.fromMap,
    );
  }

  static dynamic getUserByUid(String uid) {
    final employee = employeeByUid(uid);
    if (employee != null) return employee;
    return adminByUid(uid);
  }

  static RoleModel? roleByUid(String uid) {
    return _getEntity<RoleModel>(
      uid: uid,
      configKey: 'role',
      fromMap: RoleModel.fromMap,
    );
  }

  static DepartmentModel? departmentByUid(String uid) {
    return _getEntity<DepartmentModel>(
      uid: uid,
      configKey: 'department',
      fromMap: DepartmentModel.fromMap,
    );
  }

  static SubDepartmentModel? subDepartmentByUid(String uid) {
    return _getEntity<SubDepartmentModel>(
      uid: uid,
      configKey: 'subDepartment',
      fromMap: SubDepartmentModel.fromMap,
    );
  }

  static DesignationModel? designationByUid(String uid) {
    return _getEntity<DesignationModel>(
      uid: uid,
      configKey: 'designation',
      fromMap: DesignationModel.fromMap,
    );
  }

  static LeadStatusModel? leadStatusByUid(String uid) {
    return _getEntity<LeadStatusModel>(
      uid: uid,
      configKey: 'leadStatus',
      fromMap: LeadStatusModel.fromMap,
    );
  }

  static LeadCategoryModel? leadCategoryByUid(String uid) {
    return _getEntity<LeadCategoryModel>(
      uid: uid,
      configKey: 'leadCategory',
      fromMap: LeadCategoryModel.fromMap,
    );
  }

  static LeadPriorityModel? leadPriorityByUid(String uid) {
    return _getEntity<LeadPriorityModel>(
      uid: uid,
      configKey: 'leadPriority',
      fromMap: LeadPriorityModel.fromMap,
    );
  }

  static DealStatusModel? dealStatusByUid(String uid) {
    return _getEntity<DealStatusModel>(
      uid: uid,
      configKey: 'dealStatus',
      fromMap: DealStatusModel.fromMap,
    );
  }

  static ProjectModel? getProjectByUid(String uid) {
    return _getEntity<ProjectModel>(
      uid: uid,
      configKey: 'project',
      fromMap: ProjectModel.fromMap,
    );
  }

  static TaskModel? getTaskByUid(String uid) {
    return _getEntity<TaskModel>(
      uid: uid,
      configKey: 'task',
      fromMap: TaskModel.fromMap,
    );
  }

  // ---------------- LISTENABLE ACCESSORS ----------------

  ValueListenable<List<EmployeeModel>> getAllListenableEmployees() {
    final conf = _config['employee']!;
    if (!Hive.isBoxOpen(conf.boxName)) {
      return ValueNotifier(<EmployeeModel>[]);
    }
    return Hive.box<Map<dynamic, dynamic>>(conf.boxName).listenable().map((
      box,
    ) {
      return box.keys.map((key) {
        final value = normalizeFromCache(box.get(key) ?? {});
        return EmployeeModel.fromMap(key.toString(), value);
      }).toList();
    });
  }

  // ---------------- BULK SYNC FUNCTIONS ----------------

  /// Syncs specific collections based on the keys passed (e.g. ['employee', 'department'])
  /// If keys is empty, it syncs nothing.
  static Future<void> syncSelectedCollections(List<String> configKeys) async {
    if (configKeys.isEmpty) return;

    debugPrint("CacheService: Syncing selected: $configKeys");
    if (!(await Spdb.checkLogin())) return;

    // Each list is independent: one failing (e.g. no permission) must not
    // stop the others.
    await Future.wait(configKeys.map((key) async {
      final conf = _config[key];
      if (conf == null) return;
      try {
        final data = await _load(key);
        final box = Hive.box<Map<dynamic, dynamic>>(conf.boxName);
        await box.clear();
        await box.putAll(data);
        debugPrint("Synced ${conf.boxName} (${data.length})");
      } catch (e) {
        debugPrint("Sync $key failed: $e");
      }
    }));

    if (Hive.isBoxOpen(_metaBox)) {
      Hive.box(_metaBox).put('lastSync', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Original Full Sync (Retained for periodic background tasks)
  static Future<void> syncAllCollections() async {
    await syncSelectedCollections(_config.keys.toList());
  }

  // ---------------- UTILS ----------------

  Future<void> clearAllBoxes() async {
    try {
      for (var conf in _config.values) {
        await Hive.box<Map<dynamic, dynamic>>(conf.boxName).clear();
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  DateTime? getLastSyncTime() {
    // Box may be unavailable if it failed to open; don't crash the UI.
    if (!Hive.isBoxOpen(_metaBox)) return null;
    final metaBox = Hive.box(_metaBox);
    final ts = metaBox.get('lastSync');
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> dispose() async {
    _periodicTimer?.cancel();
  }
}

// Extension to map ValueListenable<Box> to ValueListenable<List<T>>
extension ValueListenableExtension<K, V> on ValueListenable<Box<V>> {
  ValueListenable<T> map<T>(T Function(Box<V> box) mapper) {
    return _MappedValueListenable(this, mapper);
  }
}

class _MappedValueListenable<K, V, T> extends ValueListenable<T> {
  final ValueListenable<Box<V>> original;
  final T Function(Box<V> box) mapper;

  _MappedValueListenable(this.original, this.mapper);

  @override
  T get value => mapper(original.value);

  @override
  void addListener(VoidCallback listener) => original.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      original.removeListener(listener);
}