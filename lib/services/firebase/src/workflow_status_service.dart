import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/services/services.dart';

/// One row of the Task Status / Ticket Status master (masters.php).
class WorkflowStatus {
  final String uid;
  final String name;
  final String statusKey;
  final String description;
  final int color;
  final int orderIndex;

  /// tasks: `is_completed`, tickets: `is_closed`.
  final bool isFinal;
  final DateTime? createdAt;
  final String createdByName;
  final String? createdByPhoto;

  /// Number of tasks / tickets currently using this status.
  final int usageCount;

  const WorkflowStatus({
    required this.uid,
    required this.name,
    required this.statusKey,
    required this.description,
    required this.color,
    required this.orderIndex,
    required this.isFinal,
    required this.createdAt,
    required this.createdByName,
    required this.createdByPhoto,
    required this.usageCount,
  });

  Color get colorValue => Color(color);
  bool get isAssigned => usageCount > 0;
}

/// Task status / ticket status master – backed by masters.php
/// (`type=task_status` / `type=ticket_status`). No Firestore.
class WorkflowStatusService {
  final String type;
  final bool isTicket;
  const WorkflowStatusService._(this.type, this.isTicket);

  static const task = WorkflowStatusService._(MasterTypes.taskStatus, false);
  static const ticket = WorkflowStatusService._(MasterTypes.ticketStatus, true);

  String get _finalKey => isTicket ? 'is_closed' : 'is_completed';
  String get _countKey => isTicket ? 'ticket_count' : 'task_count';
  String get label => isTicket ? 'Ticket Status' : 'Task Status';

  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e, $st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  WorkflowStatus _map(Map<String, dynamic> m) => WorkflowStatus(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        statusKey: Js.s(m['status_key']),
        description: Js.s(m['description']),
        color: ApiMappers.colorFromServer(m['color'], 0xFF64748B),
        orderIndex: Js.i(m['order_index']) ?? 0,
        isFinal: Js.b(m[_finalKey]),
        createdAt: Js.dt(m['created_at']),
        createdByName: Js.s(m['created_by_name'], 'System'),
        createdByPhoto: ApiMappers.photo(m['created_by_photo']),
        usageCount: Js.i(m[_countKey]) ?? 0,
      );

  Future<List<Map<String, dynamic>>> _fetchRows() async {
    final res = (await MastersApiService.list(type)).ensureSuccess();
    return res.dataList.map(Js.m).toList();
  }

  /// Shared, short-lived cache (see ApiLive.cached). Writes drop it.
  Future<List<Map<String, dynamic>>> _rows({bool fresh = false}) =>
      fresh ? _fetchRows() : ApiLive.cached(type, _fetchRows);

  /// All statuses ordered by `order_index` (server order).
  Future<List<WorkflowStatus>> getAll({bool fresh = false}) async {
    try {
      final list = (await _rows(fresh: fresh)).map(_map).toList();
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Next free order number (max + 1) – 6 for tasks / 7 for tickets on a
  /// fresh install, as the server seeds 5 / 6 defaults.
  Future<int> nextOrder() async {
    try {
      var max = 0;
      for (final r in await _rows(fresh: true)) {
        final o = Js.i(r['order_index']) ?? 0;
        if (o > max) max = o;
      }
      return max + 1;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  Map<String, dynamic> _body({
    required String name,
    required String statusKey,
    required String description,
    required int color,
    required int orderIndex,
    required bool isFinal,
  }) =>
      {
        'name': name.trim(),
        // Empty => the server generates the key from the name.
        if (statusKey.trim().isNotEmpty) 'status_key': statusKey.trim(),
        'description': description.trim(),
        'color': ApiMappers.colorToServer(color),
        'order_index': orderIndex,
        _finalKey: isFinal ? 1 : 0,
      };

  void _changed() => ApiLive.changed({type, isTicket ? 'tickets' : 'tasks'});

  Future<void> create({
    required String name,
    required String statusKey,
    required String description,
    required int color,
    required int orderIndex,
    required bool isFinal,
  }) async {
    try {
      (await MastersApiService.create(
        type,
        _body(
          name: name,
          statusKey: statusKey,
          description: description,
          color: color,
          orderIndex: orderIndex,
          isFinal: isFinal,
        ),
      )).ensureSuccess();
      _changed();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  Future<void> update({
    required String uid,
    required String name,
    required String statusKey,
    required String description,
    required int color,
    required int orderIndex,
    required bool isFinal,
  }) async {
    try {
      (await MastersApiService.update(
        type,
        uid,
        _body(
          name: name,
          statusKey: statusKey,
          description: description,
          color: color,
          orderIndex: orderIndex,
          isFinal: isFinal,
        ),
      )).ensureSuccess();
      _changed();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server blocks deleting a status that is (or ever was) assigned and
  /// returns the reason; it is surfaced as the thrown message.
  Future<void> delete(String uid) async {
    try {
      (await MastersApiService.delete(type, uid)).ensureSuccess();
      _changed();
    } catch (e, st) {
      _fail(e, st);
    }
  }
}