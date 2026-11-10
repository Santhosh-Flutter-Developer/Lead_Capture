import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'lead_event.dart';
part 'lead_state.dart';

/// Leads BLoC – data comes from leads.php. There is no realtime channel, so
/// lists/detail are re-fetched after every write (ApiLive.changed) and
/// polled every 30 s.
class LeadBloc extends Bloc<LeadEvent, LeadState> {
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

  LeadDetailLoaded _detail() => LeadDetailLoaded(
    comments: _comments,
    history: _history,
    activities: _activities,
  );

  Future<void> _streamLeads(StreamLead event, Emitter<LeadState> emit) async {
    emit(LeadLoading());
    await emit.forEach<Map<String, dynamic>>(
      ApiLive.watch({'leads', 'lead_status', 'deals'}, () async {
        final leads = await LeadService.getAllLeads();
        final status = await LeadStatusService.getAllLeadStatus();
        status.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
        return {'leads': leads, 'status': status};
      }),
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
      await LeadService.deleteLead(uid: event.uid);
      add(StreamLead());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadError("Failed to delete lead: $e"));
    }
  }

  Future<void> _streamLeadComments(
    StreamLeadComments event,
    Emitter<LeadState> emit,
  ) async {
    await emit.forEach<List<LeadCommentModel>>(
      ApiLive.watch({'lead_${event.leadUid}'}, () => LeadService.getComments(event.leadUid)),
      onData: (comments) {
        _comments = comments;
        return _detail();
      },
      onError: (error, st) => LeadDetailError("Failed to load comments"),
    );
  }

  Future<void> _addLeadComment(
    AddLeadComment event,
    Emitter<LeadState> emit,
  ) async {
    try {
      final user = await Spdb.getUser();
      await LeadService.addLeadComment(
        leadUid: event.leadUid,
        comment: LeadCommentModel(
          userId: user.uid,
          comment: event.commentText,
          createdBy: user,
        ),
      );
    } catch (e) {
      emit(LeadDetailError("Failed to add comment"));
    }
  }

  Future<void> _streamLeadActivities(
    StreamLeadActivities event,
    Emitter<LeadState> emit,
  ) async {
    await emit.forEach<List<LeadActivityModel>>(
      ApiLive.watch({'lead_${event.leadUid}'}, () async {
        final a = await LeadService.getActivities(event.leadUid);
        a.sort((x, y) => x.scheduledAt.compareTo(y.scheduledAt));
        return a;
      }),
      onData: (activities) {
        _activities = activities;
        return _detail();
      },
      onError: (error, st) => LeadDetailError("Failed to load activities"),
    );
  }

  Future<void> _addLeadActivity(
    AddLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    try {
      // Server records history, notifies, and the calendar reads activities.
      await LeadService.addActivity(leadUid: event.leadUid, activity: event.activity);
    } catch (e) {
      emit(LeadError(e.toString()));
    }
  }

  /// leads.php has no edit/delete activity action (MISSING_API_REQUIREMENTS.md).
  Future<void> _editLeadActivity(
    EditLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    emit(LeadError('Editing activities is not supported by the server yet.'));
  }

  Future<void> _deleteLeadActivity(
    DeleteLeadActivity event,
    Emitter<LeadState> emit,
  ) async {
    emit(LeadError('Deleting activities is not supported by the server yet.'));
  }

  Future<void> _streamLeadHistory(
    StreamLeadHistory event,
    Emitter<LeadState> emit,
  ) async {
    await emit.forEach<List<LeadHistoryModel>>(
      ApiLive.watch({'lead_${event.leadUid}'}, () => LeadService.getHistory(event.leadUid)),
      onData: (history) {
        _history = history;
        return _detail();
      },
      onError: (error, st) => LeadDetailError("Failed to load history"),
    );
  }
}
