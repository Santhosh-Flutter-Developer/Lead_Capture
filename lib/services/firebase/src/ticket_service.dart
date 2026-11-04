import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class TicketService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createTicket({
    required CustomerTicketModel ticket,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      if (!ticket.createdBy.contains(uid)) {
        ticket.createdBy.add(uid!);
      }

      final userDoc = firebase.users.doc(cid);
      final ticketsRef = userDoc.collection(Collections.customerTickets.name);

      // Generate ticket number if not provided
      int ticketNumber = ticket.ticketNumber ?? 1;
      var lastTicketSnapshot = await ticketsRef
          .orderBy('ticketNumber', descending: true)
          .limit(1)
          .get();
      if (lastTicketSnapshot.docs.isNotEmpty) {
        ticketNumber =
            (lastTicketSnapshot.docs.first.data()['ticketNumber'] ?? 0) + 1;
      }

      var ticketData = ticket.toMap();
      ticketData['ticketNumber'] = ticketNumber;

      var ticketDoc = await ticketsRef.add(ticketData);

      // Ticket History
      TicketHistoryModel ticketHistoryModel = TicketHistoryModel(
        userId: uid ?? '',
        updateDisposition: 'Ticket Created',
      );

      await ticketDoc
          .collection(Collections.ticketHistory.name)
          .add(ticketHistoryModel.toMap());

      // Created straight into "In Progress" => time tracking starts now.
      await _syncTimeLog(
        ticketRef: ticketDoc,
        oldStatus: null,
        newStatus: ticket.status,
        userId: uid ?? '',
      );

      // Who should be notified: an employee-created ticket notifies the
      // creator + every admin; an admin-created ticket notifies admins only.
      List<String> users = await NotificationRecipientService.forRecord(
        createdBy: ticket.ticketCreatedBy,
      );

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Ticket : ${ticket.ticketTitle}',
        body: 'New ticket created by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.ticket,
        payload: {'ticketId': ticketDoc.id},
      );

      PostNotificationService.sendNotification(model: notif);

      if (ticket.reminder != null) {
        ReminderService.createReminder(
          scheduledAt: ticket.reminder!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Ticket Reminder',
            body: 'Ticket "${ticket.ticketTitle}" reminder',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.ticket,
            payload: {'ticketId': ticketDoc.id},
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error creating ticket: $e';
    }
  }

  static Future<void> updateTicket({
    required String uid,
    required CustomerTicketModel ticket,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var userId = await Spdb.getUid();

      final ticketRef = firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid);

      // Status before the edit, so the time tracker can follow the change.
      final before = await ticketRef.get();
      final oldStatus = before.exists
          ? TicketStatus.values.firstWhere(
              (e) => e.name == (before.data()?['status'] as String?),
              orElse: () => TicketStatus.open,
            )
          : null;

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.customerTickets.name}',
        uid,
        ticket.toUpdateMap(),
        activity: '${ticket.ticketTitle} has been updated',
      );

      await _syncTimeLog(
        ticketRef: ticketRef,
        oldStatus: oldStatus,
        newStatus: ticket.status,
        userId: userId ?? '',
      );

      TicketHistoryModel ticketHistoryModel = TicketHistoryModel(
        userId: userId ?? '',
        updateDisposition: 'Ticket Updated',
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .collection(Collections.ticketHistory.name)
          .add(ticketHistoryModel.toMap());

      List<String> users = [
        ...ticket.assignTo,
        ...ticket.participants,
        ...ticket.createdBy,
        ...ticket.observers,
      ];

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Ticket : ${ticket.ticketTitle}',
        body: 'Ticket has updated by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.ticket,
        payload: {'ticketId': uid},
      );

      PostNotificationService.sendNotification(model: notif);

      if (ticket.reminder != null) {
        ReminderService.createReminder(
          scheduledAt: ticket.reminder!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Ticket Reminder',
            body: 'Ticket "${ticket.ticketTitle}" reminder',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.ticket,
            payload: {'ticketId': uid},
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error updating ticket: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error updating ticket: $e';
    }
  }

  // Delete ticket
  static Future<void> deleteTicket({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['ticketTitle'] ?? 'N/A'} has been deleted',
        description:
            'User has deleted an entry in ${Collections.customerTickets.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.customerTickets.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting ticket: $e';
    }
  }

  static Future<void> restoreTicket(CustomerTicketModel ticket) async {
    try {
      final FirebaseConfig firebase = FirebaseConfig();
      final cid = await Spdb.getCid();

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticket.uid)
          .set(ticket.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // Get a single ticket
  static Future<CustomerTicketModel> getTicket({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(uid)
          .get();

      if (!doc.exists) throw 'Ticket not found';
      return CustomerTicketModel.fromMap(doc.id, doc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching ticket: $e';
    }
  }

  // Get all tickets
  static Future<List<CustomerTicketModel>> getAllTickets() async {
    try {
      var cid = await Spdb.getCid();
      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .get();

      return snapshot.docs
          .map((doc) => CustomerTicketModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching tickets: $e';
    }
  }

  static const String _timeLogs = 'ticketTimeLogs';

  /// Keeps the time tracker in step with a status change: a session opens
  /// when the ticket enters In Progress and closes when it leaves it
  /// (hold, pending customer response, resolved, closed).
  static Future<void> _syncTimeLog({
    required DocumentReference<Map<String, dynamic>> ticketRef,
    required TicketStatus? oldStatus,
    required TicketStatus newStatus,
    required String userId,
  }) async {
    final wasRunning = oldStatus?.isTimerRunning ?? false;
    final nowRunning = newStatus.isTimerRunning;
    if (wasRunning == nowRunning) return;

    final logs = ticketRef.collection(_timeLogs);
    final open = await logs.where('endTime', isNull: true).limit(1).get();

    if (nowRunning) {
      if (open.docs.isEmpty) {
        await logs.add({
          'userId': userId,
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'endTime': null,
        });
      }
    } else if (open.docs.isNotEmpty) {
      await open.docs.first.reference.update({
        'endTime': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Changes only the status of a ticket (status dropdown in the ticket view).
  /// Records history + time tracking and notifies everyone on the ticket.
  static Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus newStatus,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();
      if (uid == null) throw 'User not logged in';

      final ticketRef = firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId);

      // Decide from the latest server state, not from what the screen shows.
      final snap = await ticketRef.get();
      final data = snap.data();
      if (!snap.exists || data == null) throw 'Ticket not found';
      final ticket = CustomerTicketModel.fromMap(snap.id, data);
      final current = ticket.status;
      if (current == newStatus) return;

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.customerTickets.name}',
        ticketId,
        {
          'status': newStatus.name,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        activity: '${ticket.ticketTitle} status changed',
      );

      await _syncTimeLog(
        ticketRef: ticketRef,
        oldStatus: current,
        newStatus: newStatus,
        userId: uid,
      );

      await ticketRef
          .collection(Collections.ticketHistory.name)
          .add(
            TicketHistoryModel(
              userId: uid,
              updateDisposition:
                  'Status changed: ${current.label} → ${newStatus.label}',
            ).toMap(),
          );

      // Notification problems must never undo a successful status change.
      try {
        final users = {
          ...ticket.assignTo,
          ...ticket.participants,
          ...ticket.createdBy,
          ...ticket.observers,
        }.toList();
        final fcmIds = <String>[];
        for (final u in users) {
          fcmIds.addAll(await AuthService.getUserFcmIds(uid: u));
        }
        final user = await Spdb.getUser();
        PostNotificationService.sendNotification(
          model: NotificationModel(
            collectionId: cid ?? '',
            title: 'Ticket : ${ticket.ticketTitle}',
            body: '${user.name} changed status to ${newStatus.label}',
            toFcms: fcmIds,
            toUids: users,
            senderId: uid,
            type: NotificationType.ticket,
            payload: {'ticketId': ticketId},
          ),
        );
      } catch (e, st) {
        await ErrorService.recordError(e, st);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  /// Work sessions (In Progress -> hold/resolved/closed) of a ticket, oldest
  /// first.
  static Stream<List<TaskTimeLogModel>> streamTimeLogs({
    required String cid,
    required String ticketId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .doc(ticketId)
        .collection(_timeLogs)
        .orderBy('startTime')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TaskTimeLogModel.fromMap(d.data())).toList(),
        )
        .asBroadcastStream();
  }

  static Stream<List<TicketHistoryModel>> streamTicketHistory({
    required String cid,
    required String ticketId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .doc(ticketId)
        .collection(Collections.ticketHistory.name)
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TicketHistoryModel.fromMap(d.data()))
              .toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Stream<List<TicketCommentModel>> streamComments({
    required String cid,
    required String ticketId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .doc(ticketId)
        .collection(Collections.ticketComments.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TicketCommentModel.fromMap(d.data()))
              .toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Future<List<TicketHistoryModel>> getTicketHistory({
    required String ticketId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketHistory.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TicketHistoryModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting ticket history: $e';
    }
  }

  static Future<List<TicketCommentModel>> getComments({
    required String ticketId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketComments.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TicketCommentModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting comments: $e';
    }
  }

  static Future<void> addComment({
    required String ticketId,
    required String comment,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      TicketCommentModel commentModel = TicketCommentModel(
        userId: uid ?? '',
        comment: comment,
        timestamp: DateTime.now(),
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .doc(ticketId)
          .collection(Collections.ticketComments.name)
          .add(commentModel.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error adding comment: $e';
    }
  }
}