import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_event.dart';
part 'lead_state.dart';

class LeadBloc extends Bloc<LeadEvent, LeadState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<LeadModel> allLeads = [];
  List<LeadStatusModel> allStatus = [];
  List<LeadCommentModel> _comments = [];
  List<LeadHistoryModel> _history = [];
  List<LeadActivityModel> _activities = [];

  LeadBloc() : super(LeadLoading()) {
    on<StreamLead>(_streamLeads);
    on<DeleteLead>(_deleteLead);
    on<StreamLeadComments>(_streamLeadComments);
    on<AddLeadComment>(_addLeadComment);
    on<StreamLeadHistory>(_streamLeadHistory);
    on<StreamLeadActivities>(_streamLeadActivities);
    on<AddLeadActivity>(_addLeadActivity);
    on<EditLeadActivity>(_editLeadActivity);
    on<DeleteLeadActivity>(_deleteLeadActivity);
  }

  Future<void> _streamLeads(StreamLead event, Emitter<LeadState> emit) async {
    emit(LeadLoading());
    final cid = await Spdb.getCid();

    final leadsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .snapshots()
        .asyncMap(
          (snapshot) => FollowUpAccess.filterVisible(
            snapshot.docs
                .map((doc) => LeadModel.fromMap(doc.id, doc.data()))
                .toList(),
            // Follow Up set -> only that employee + admins see the lead.
            (l) => l.followUp,
          ),
        );

    final statusStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leadStatus.name)
        .orderBy('orderNumber', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeadStatusModel.fromMap(doc.id, doc.data()))
              .toList(),
        );

    // Combine both streams
    await emit.forEach(
      Rx.combineLatest2<
        List<LeadModel>,
        List<LeadStatusModel>,
        Map<String, dynamic>
      >(
        leadsStream,
        statusStream,
        (leads, status) => {'leads': leads, 'status': status},
      ),
      onData: (data) {
        allLeads = data['leads'];
        allStatus = data['status'];
        return LeadLoaded(allLeads, allStatus);
      },
      onError: (error, stackTrace) {
        debugPrint(stackTrace.toString());
        return LeadError("Failed to load leads: $error");
      },
    );
  }

  Future<void> _deleteLead(DeleteLead event, Emitter<LeadState> emit) async {
    try {
      final cid = await Spdb.getCid();

      var docRef = await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();

      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: await Spdb.getUser(),
        activity: '${data['leadName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.admins.name}',
        collection: '${Collections.users.name}/$cid/${Collections.admins.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.leads.name}',
        activityLogModel.toMap(),
      );
      add(StreamLead());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint(st.toString());
      emit(LeadError("Failed to delete lead: $e"));
    }
  }

  Future<void> _streamLeadComments(
    StreamLeadComments event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final commentsStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              var data = doc.data();
              data['uid'] = doc.id;
              return LeadCommentModel.fromMap(data);
            }).toList(),
          );

      await emit.forEach(
        commentsStream,
        onData: (comments) {
          _comments = comments;
          return LeadDetailLoaded(
            comments: _comments,
            history: _history,
            activities: _activities,
          );
        },
        onError: (error, stackTrace) {
          debugPrint(stackTrace.toString());
          return LeadDetailError("Failed to load comments");
        },
      );
    } catch (e) {
      emit(LeadDetailError("Failed to load comments: $e"));
    }
  }

  Future<void> _addLeadComment(
    AddLeadComment event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      LeadCommentModel comment = LeadCommentModel(
        userId: user.uid,
        comment: event.commentText,
        attachments: [],
        timestamp: DateTime.now(),
        createdBy: user,
      );

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('comments')
          .add(comment.toMap());

      // Add history entry
      await LeadService.addLeadHistory(
        leadUid: event.leadUid,
        action: "${user.name} added a comment",
      );
    } catch (e, st) {
      debugPrint(st.toString());
      emit(LeadDetailError("Failed to add comment"));
    }
  }

  Future<void> _streamLeadActivities(
    StreamLeadActivities event,
    Emitter<LeadState> emit,
  ) async {
    final cid = await Spdb.getCid();

    final stream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .doc(event.leadUid)
        .collection('activities')
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LeadActivityModel.fromMap(doc.id, doc.data()))
              .toList();
        });

    await emit.forEach<List<LeadActivityModel>>(
      stream,
      onData: (activities) {
        _activities = activities;

        return LeadDetailLoaded(
          comments: _comments,
          history: _history,
          activities: _activities,
        );
      },
    );
  }

  Future<void> _addLeadActivity(
    AddLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      final activityRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('activities')
          .doc();

      await activityRef.set(event.activity.toMap());

      final calendarEventId = LeadService.leadActivityCalendarDocId(
        leadUid: event.leadUid,
        activityUid: activityRef.id,
      );

      final calendarEvent = EventModel(
        eventName: event.activity.title,
        eventDateTime: event.activity.scheduledAt,
        eventEndDateTime: event.activity.scheduledAt.add(
          const Duration(hours: 1),
        ),
        eventDescription: event.activity.description.isNotEmpty
            ? event.activity.description
            : 'Lead activity scheduled',
        eventRepeatType: EventRepeatType.none,
        eventAttendes: [user.uid],
        createdBy: user,
      );

      try {
        await EventService.createEvent(
          event: calendarEvent,
          docId: calendarEventId,
        );
      } catch (e, st) {
        debugPrint('Failed to mirror lead activity to calendar: $e\n$st');
      }

      await LeadService.addLeadHistory(
        leadUid: event.leadUid,
        action: "New activity scheduled",
      );

      // Send notification to lead workflow members
      try {
        final leadDoc = await firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.leads.name)
            .doc(event.leadUid)
            .get();
        final leadData = leadDoc.data();
        if (leadData != null) {
          final lead = LeadModel.fromMap(leadDoc.id, leadData);
          List<String> users = lead.workflow.toSet().toList();
          users.add(lead.createdBy.uid);
          users = users.toSet().toList();

          List<String> toUids = List<String>.from(users);
          List<String> fcmIds = [];
          for (var uid in users) {
            fcmIds.addAll(await AuthService.getUserFcmIds(uid: uid));
          }

          var notif = NotificationModel(
            collectionId: cid ?? '',
            title: 'Lead Activity: ${event.activity.title}',
            body:
                '${user.name} scheduled "${event.activity.title}" for ${lead.leadName}',
            createdAt: DateTime.now(),
            toFcms: fcmIds,
            toUids: toUids,
            senderId: user.uid,
            type: NotificationType.lead,
            payload: {'leadId': event.leadUid},
          );
          await PostNotificationService.sendNotification(model: notif);
        }
      } catch (e, st) {
        debugPrint('Failed to send activity notification: $e\n$st');
      }
    } catch (e) {
      emit(LeadError(e.toString()));
    }
  }

  Future<void> _editLeadActivity(
    EditLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('activities')
          .doc(event.activity.uid)
          .update(event.activity.toMap());

      final calendarEventId = LeadService.leadActivityCalendarDocId(
        leadUid: event.leadUid,
        activityUid: event.activity.uid!,
      );

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.events.name)
          .doc(calendarEventId)
          .update({
            'eventName': event.activity.title,
            'eventDateTime': event.activity.scheduledAt.millisecondsSinceEpoch,
            'eventEndDateTime': event.activity.scheduledAt
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            'eventDescription': event.activity.description.isNotEmpty
                ? event.activity.description
                : 'Lead activity scheduled',
          });

      await LeadService.addLeadHistory(
        leadUid: event.leadUid,
        action: "Activity updated: ${event.activity.title}",
      );

      // Send notification to lead workflow members
      try {
        final leadDoc = await firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.leads.name)
            .doc(event.leadUid)
            .get();
        final leadData = leadDoc.data();
        if (leadData != null) {
          final lead = LeadModel.fromMap(leadDoc.id, leadData);
          List<String> users = lead.workflow.toSet().toList();
          users.add(lead.createdBy.uid);
          users = users.toSet().toList();

          List<String> toUids = List<String>.from(users);
          List<String> fcmIds = [];
          for (var uid in users) {
            fcmIds.addAll(await AuthService.getUserFcmIds(uid: uid));
          }

          final user = await Spdb.getUser();
          var notif = NotificationModel(
            collectionId: cid ?? '',
            title: 'Lead Activity Updated: ${event.activity.title}',
            body:
                '${user.name} updated activity "${event.activity.title}" for ${lead.leadName}',
            createdAt: DateTime.now(),
            toFcms: fcmIds,
            toUids: toUids,
            senderId: user.uid,
            type: NotificationType.lead,
            payload: {'leadId': event.leadUid},
          );
          await PostNotificationService.sendNotification(model: notif);
        }
      } catch (e, st) {
        debugPrint('Failed to send activity update notification: $e\n$st');
      }
    } catch (e) {
      emit(LeadError(e.toString()));
    }
  }

  Future<void> _deleteLeadActivity(
    DeleteLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('activities')
          .doc(event.activityUid)
          .delete();

      final calendarEventId = LeadService.leadActivityCalendarDocId(
        leadUid: event.leadUid,
        activityUid: event.activityUid,
      );

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.events.name)
          .doc(calendarEventId)
          .delete();

      await LeadService.addLeadHistory(
        leadUid: event.leadUid,
        action: "Activity deleted",
      );
    } catch (e) {
      emit(LeadError(e.toString()));
    }
  }

  Future<void> _streamLeadHistory(
    StreamLeadHistory event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final historyStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .doc(event.leadUid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => LeadHistoryModel.fromMap(doc.data()))
                .toList(),
          );

      await emit.forEach(
        historyStream,
        onData: (history) {
          _history = history;
          return LeadDetailLoaded(
            comments: _comments,
            history: _history,
            activities: _activities,
          );
        },
        onError: (error, _) => LeadDetailError(error.toString()),
      );
    } catch (e) {
      emit(LeadDetailError(e.toString()));
    }
  }
}