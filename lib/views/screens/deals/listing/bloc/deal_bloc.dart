import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'deal_event.dart';
part 'deal_state.dart';

/// Deals BLoC – deals.php, re-fetched after writes and polled every 30 s.
class DealBloc extends Bloc<DealEvent, DealState> {
  List<DealModel> allDeals = [];
  List<DealStatusModel> allStatus = [];
  List<DealCommentModel> _comments = [];
  List<DealHistoryModel> _history = [];
  List<DealActivityModel> _activities = [];

  DealBloc() : super(DealLoading()) {
    on<StreamDeals>(_streamDeals);
    on<DeleteDeal>(_deleteDeal);
    on<StreamDealComments>(_streamDealComments);
    on<AddDealComment>(_addDealComment);
    on<StreamDealHistory>(_streamDealHistory);
    on<AddDealHistory>(_addDealHistory);
    on<StreamDealActivities>(_streamDealActivities);
    on<AddDealActivity>(_addDealActivity);
    on<EditDealActivity>(_editDealActivity);
    on<DeleteDealActivity>(_deleteDealActivity);
  }

  DealDetailLoaded _detail() => DealDetailLoaded(
    comments: _comments,
    history: _history,
    activities: _activities,
  );

  Future<void> _streamDeals(StreamDeals event, Emitter<DealState> emit) async {
    emit(DealLoading());
    await emit.forEach<Map<String, dynamic>>(
      ApiLive.watch({'deals', 'deal_status', 'leads'}, () async {
        final deals = await DealService.getAllDeals();
        final status = await DealStatusService.getAllDealStatus();
        status.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
        return {'deals': deals, 'status': status};
      }),
      onData: (data) {
        allDeals = data['deals'];
        allStatus = data['status'];
        return DealLoaded(allDeals, allStatus);
      },
      onError: (error, stackTrace) {
        debugPrint(stackTrace.toString());
        return DealError("Failed to load deals: $error");
      },
    );
  }

  Future<void> _deleteDeal(DeleteDeal event, Emitter<DealState> emit) async {
    try {
      await DealService.deleteDeal(uid: event.dealUid);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(DealError("Failed to delete deal: $e"));
    }
  }

  Future<void> _streamDealComments(StreamDealComments event, Emitter<DealState> emit) async {
    await emit.forEach<List<DealCommentModel>>(
      ApiLive.watch({'deal_${event.dealUid}'}, () => DealService.getComments(event.dealUid)),
      onData: (c) {
        _comments = c;
        return _detail();
      },
      onError: (e, st) => DealDetailError("Failed to load comments"),
    );
  }

  Future<void> _addDealComment(AddDealComment event, Emitter<DealState> emit) async {
    try {
      final user = await Spdb.getUser();
      await DealService.addDealComment(
        dealUid: event.dealUid,
        commentText: DealCommentModel(userId: user.uid, comment: event.commentText, createdBy: user),
      );
    } catch (e) {
      emit(DealDetailError("Failed to add comment"));
    }
  }

  Future<void> _streamDealHistory(StreamDealHistory event, Emitter<DealState> emit) async {
    await emit.forEach<List<DealHistoryModel>>(
      ApiLive.watch({'deal_${event.dealUid}'}, () => DealService.getHistory(event.dealUid)),
      onData: (h) {
        _history = h;
        return _detail();
      },
      onError: (e, st) => DealDetailError("Failed to load history"),
    );
  }

  /// History is written by the server for every action.
  Future<void> _addDealHistory(AddDealHistory event, Emitter<DealState> emit) async {}

  Future<void> _streamDealActivities(StreamDealActivities event, Emitter<DealState> emit) async {
    await emit.forEach<List<DealActivityModel>>(
      ApiLive.watch({'deal_${event.dealUid}'}, () async {
        final a = await DealService.getActivities(event.dealUid);
        a.sort((x, y) => x.scheduledAt.compareTo(y.scheduledAt));
        return a;
      }),
      onData: (a) {
        _activities = a;
        return _detail();
      },
      onError: (e, st) => DealDetailError("Failed to load activities"),
    );
  }

  Future<void> _addDealActivity(AddDealActivity event, Emitter<DealState> emit) async {
    try {
      await DealService.addActivity(dealUid: event.dealUid, activity: event.activity);
    } catch (e) {
      emit(DealError(e.toString()));
    }
  }

  /// deals.php has no edit/delete activity action.
  Future<void> _editDealActivity(EditDealActivity event, Emitter<DealState> emit) async {
    emit(DealError('Editing activities is not supported by the server yet.'));
  }

  Future<void> _deleteDealActivity(DeleteDealActivity event, Emitter<DealState> emit) async {
    emit(DealError('Deleting activities is not supported by the server yet.'));
  }
}
