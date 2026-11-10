import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Support tickets – backed by tickets.php (no Firestore). No history table
/// or time-log endpoint exists on the server (history is empty, time logs
/// are empty).
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
    'status': t.status.name,
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

  static Future<void> deleteTicket({required String uid}) async {
    try {
      (await TicketsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'tickets', 'trash'});
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

  /// No time-log endpoint in tickets.php.
  static Stream<List<TaskTimeLogModel>> streamTimeLogs({
    required String cid,
    required String ticketId,
  }) => Stream.value(<TaskTimeLogModel>[]);

  static Stream<List<TicketHistoryModel>> streamTicketHistory({
    required String cid,
    required String ticketId,
  }) => Stream.value(<TicketHistoryModel>[]);

  static Stream<List<TicketCommentModel>> streamComments({
    required String cid,
    required String ticketId,
  }) => ApiLive.watch({'ticket_$ticketId'}, () async {
    final l = Js.mapList((await _detail(ticketId))['comments']).map(CrmMappers.ticketComment).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Future<List<TicketHistoryModel>> getTicketHistory({required String ticketId}) async =>
      <TicketHistoryModel>[];

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
