import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Support tickets – backed by tickets.php (no Firestore). History and time
/// logs come from the `get` response (activity_history, timelogs).
class TicketService {
  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e\n$st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static Map<String, dynamic> _body(CustomerTicketModel t) => {
    'master_client_id': t.masterClientId ?? '',
    'client_name': t.clientName,
    'client_company_name': t.clientCompanyName ?? '',
    'mode_of_contact': t.modeOfContact.name,
    'ticket_title': t.ticketTitle,
    'ticket_description': t.ticketDescription,
    'assign_to': t.assignTo,
    'participants': t.participants,
    'observers': t.observers,
    'priority_level': t.priorityLevel.name,
    'category': t.category.label,
    // Raw master key (custom statuses like "reopen" have no enum value).
    'status': (t.statusKey ?? '').isNotEmpty ? t.statusKey : t.status.name,
    'deadline': t.deadline?.toIso8601String(),
    'reminder': t.reminder?.toIso8601String(),
    'project': t.project ?? '',
    'task': t.task ?? '',
    'attachment_ids': CrmMappers.attachmentIds(t.attachments),
  };

  static Future<void> createTicket({required CustomerTicketModel ticket}) async {
    try {
      (await TicketsApiService.call('create', _body(ticket))).ensureSuccess();
      ApiLive.changed('tickets');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> updateTicket({
    required String uid,
    required CustomerTicketModel ticket,
  }) async {
    try {
      (await TicketsApiService.call('update', {'uid': uid, ..._body(ticket)})).ensureSuccess();
      ApiLive.changed({'tickets', 'ticket_$uid'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// "Delete" = Cancel with remarks (tickets.php `cancel`). The server
  /// refuses when the status was ever changed; the ticket stays in the list.
  static Future<void> cancelTicket({
    required String uid,
    required String remarks,
  }) async {
    try {
      if (remarks.trim().isEmpty) throw 'Cancellation remarks are required.';
      (await TicketsApiService.call('cancel', {
        'uid': uid,
        'remarks': remarks.trim(),
      })).ensureSuccess();
      ApiLive.changed({'tickets', 'ticket_$uid'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Bulk cancel (`bulk_cancel`); returns the server message.
  static Future<String> cancelTickets({
    required List<String> uids,
    required String remarks,
  }) async {
    try {
      if (remarks.trim().isEmpty) throw 'Cancellation remarks are required.';
      final res = (await TicketsApiService.call('bulk_cancel', {
        'uids': uids,
        'remarks': remarks.trim(),
      })).ensureSuccess();
      ApiLive.changed('tickets');
      return res.message;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> deleteTicket({
    required String uid,
    String remarks = '',
  }) => cancelTicket(uid: uid, remarks: remarks);

  /// Built-in enum for a master key (custom keys fall back to `open`).
  static TicketStatus statusEnumFor(String key) {
    final k = key.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
    for (final e in TicketStatus.values) {
      if (e.name.toLowerCase() == k) return e;
    }
    return TicketStatus.open;
  }

  /// Ticket Status master (Creation -> Ticket Status), ordered.
  static Future<List<WorkflowStatus>> getStatuses() =>
      WorkflowStatusService.ticket.getAll();

  /// Moves the ticket to a master status chosen in the dynamic dropdown.
  static Future<void> changeStatus({
    required String ticketId,
    required WorkflowStatus target,
  }) async {
    try {
      (await TicketsApiService.call('update_status', {
        'uid': ticketId,
        'status': target.statusKey,
      })).ensureSuccess();
      ApiLive.changed({'tickets', 'ticket_$ticketId'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> restoreTicket(CustomerTicketModel ticket) async {
    throw 'Restoring a deleted ticket is not supported by the server yet.';
  }

  static Future<CustomerTicketModel> getTicket({required String uid}) async {
    try {
      final res = (await TicketsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.ticket(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<CustomerTicketModel>> getAllTickets() async {
    try {
      final res = (await TicketsApiService.call('list')).ensureSuccess();
      return res.dataList.map((r) => CrmMappers.ticket(Js.m(r))).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Tickets the current user is involved in (admins see all).
  static Future<List<CustomerTicketModel>> getMyTickets() async {
    final uid = await Spdb.getUid();
    final all = await getAllTickets();
    if (await Spdb.isAdminLoggedIn()) return all;
    return all
        .where((t) =>
            t.assignTo.contains(uid) ||
            t.createdBy.contains(uid) ||
            t.observers.contains(uid) ||
            t.participants.contains(uid))
        .toList();
  }

  static Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus newStatus,
  }) async {
    try {
      (await TicketsApiService.call('update_status', {'uid': ticketId, 'status': newStatus.name})).ensureSuccess();
      ApiLive.changed({'tickets', 'ticket_$ticketId'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<Map<String, dynamic>> _detail(String id) async =>
      (await TicketsApiService.call('get', {'uid': id})).ensureSuccess().dataMap;

  /// Work sessions = tickets.php `get` -> timelogs (opened when the status
  /// becomes In Progress, closed on hold / pending customer / resolved / closed).
  static Stream<List<TaskTimeLogModel>> streamTimeLogs({
    required String cid,
    required String ticketId,
  }) => ApiLive.watch({'ticket_$ticketId'}, () async {
    final l = Js.mapList((await _detail(ticketId))['timelogs']).map(CrmMappers.taskTimeLog).toList();
    l.sort((a, b) => a.startTime.compareTo(b.startTime));
    return l;
  });

  /// History = tickets.php `get` -> activity_history.
  static Stream<List<TicketHistoryModel>> streamTicketHistory({
    required String cid,
    required String ticketId,
  }) => ApiLive.watch({'ticket_$ticketId'}, () async {
    final l = Js.mapList((await _detail(ticketId))['activity_history']).map(CrmMappers.ticketHistory).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Stream<List<TicketCommentModel>> streamComments({
    required String cid,
    required String ticketId,
  }) => ApiLive.watch({'ticket_$ticketId'}, () async {
    final l = Js.mapList((await _detail(ticketId))['comments']).map(CrmMappers.ticketComment).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Future<List<TicketHistoryModel>> getTicketHistory({required String ticketId}) async {
    try {
      return Js.mapList((await _detail(ticketId))['activity_history']).map(CrmMappers.ticketHistory).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<TicketCommentModel>> getComments({required String ticketId}) async {
    try {
      return Js.mapList((await _detail(ticketId))['comments']).map(CrmMappers.ticketComment).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> addComment({required String ticketId, required String comment}) async {
    try {
      (await TicketsApiService.call('add_comment', {'ticket_uid': ticketId, 'comment': comment})).ensureSuccess();
      ApiLive.changed('ticket_$ticketId');
    } catch (e, st) {
      _fail(e, st);
    }
  }
}