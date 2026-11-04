import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'deal_event.dart';
part 'deal_state.dart';

class DealBloc extends Bloc<DealEvent, DealState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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

  Future<void> _streamDeals(StreamDeals event, Emitter<DealState> emit) async {
    emit(DealLoading());
    final cid = await Spdb.getCid();

    final dealsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .snapshots()
        .asyncMap(
          (snapshot) => FollowUpAccess.filterVisible(
            snapshot.docs
                .map((doc) => DealModel.fromMap(doc.id, doc.data()))
                .toList(),
            // Follow Up set -> only that employee + admins see the deal.
            (d) => d.followUp,
          ),
        );

    final statusStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.dealStatus.name)
        .orderBy('orderNumber', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DealStatusModel.fromMap(doc.id, doc.data()))
              .toList(),
        );

    await emit.forEach(
      Rx.combineLatest2<
        List<DealModel>,
        List<DealStatusModel>,
        Map<String, dynamic>
      >(
        dealsStream,
        statusStream,
        (deals, status) => {'deals': deals, 'status': status},
      ),
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
      final cid = await Spdb.getCid();

      var docRef = await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
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
        activity: '${data['dealName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.deals.name}',
        collection: '${Collections.users.name}/$cid/${Collections.deals.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('Error deleting deal: $e\n$st');
      emit(DealError("Failed to delete deal: $e"));
    }
  }

  Future<void> _streamDealComments(
    StreamDealComments event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      final commentsStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return DealCommentModel.fromMap(data);
            }).toList(),
          );

      await emit.forEach<List<DealCommentModel>>(
        commentsStream,
        onData: (comments) {
          _comments = comments;

          return DealDetailLoaded(
            comments: _comments,
            history: _history,
            activities: _activities,
          );
        },
        onError: (error, stackTrace) {
          debugPrint(stackTrace.toString());
          return DealDetailError("Failed to load comments");
        },
      );
    } catch (e) {
      emit(DealDetailError("Failed to load comments: $e"));
    }
  }

  Future<void> _addDealComment(
    AddDealComment event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      DealCommentModel comment = DealCommentModel(
        userId: user.uid,
        comment: event.commentText,
        attachments: [],
        timestamp: DateTime.now(),
        createdBy: user,
      );

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('comments')
          .add(comment.toMap());

      await DealService.addDealHistory(
        dealUid: event.dealUid,
        action: "${user.name} added a comment",
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint(st.toString());
      emit(DealDetailError("Failed to add comment"));
    }
  }

  Future<void> _streamDealHistory(
    StreamDealHistory event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      final historyStream = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DealHistoryModel.fromMap(doc.data()))
                .toList(),
          );

      await emit.forEach<List<DealHistoryModel>>(
        historyStream,
        onData: (history) {
          _history = history;
          return DealDetailLoaded(
            comments: _comments,
            history: _history,
            activities: _activities,
          );
        },
        onError: (error, _) => DealDetailError(error.toString()),
      );
    } catch (e) {
      emit(DealDetailError(e.toString()));
    }
  }

  Future<void> _addDealHistory(
    AddDealHistory event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final user = await Spdb.getUser();

      final historyRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('history');

      final history = DealHistoryModel(
        userId: user.uid,
        updateDisposition: event.action,
      );

      await historyRef.add(history.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error adding deal history: $e\n$st");
      emit(DealDetailError("Failed to add deal history"));
    }
  }

  Future<void> _streamDealActivities(
    StreamDealActivities event,
    Emitter<DealState> emit,
  ) async {
    final cid = await Spdb.getCid();

    final stream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .doc(event.dealUid)
        .collection('activities')
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DealActivityModel.fromMap(doc.id, doc.data()))
              .toList();
        });

    await emit.forEach<List<DealActivityModel>>(
      stream,
      onData: (activities) {
        _activities = activities;

        return DealDetailLoaded(
          comments: _comments,
          history: _history,
          activities: _activities,
        );
      },
    );
  }

  Future<void> _addDealActivity(
    AddDealActivity event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      final activityRef = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('activities')
          .doc();

      await activityRef.set(event.activity.toMap());

      await DealService.addDealHistory(
        dealUid: event.dealUid,
        action: "New activity scheduled",
      );
    } catch (e) {
      emit(DealError(e.toString()));
    }
  }

  Future<void> _editDealActivity(
    EditDealActivity event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('activities')
          .doc(event.activity.uid)
          .update(event.activity.toMap());

      await DealService.addDealHistory(
        dealUid: event.dealUid,
        action: "Activity updated: ${event.activity.title}",
      );
    } catch (e) {
      emit(DealError(e.toString()));
    }
  }

  Future<void> _deleteDealActivity(
    DeleteDealActivity event,
    Emitter<DealState> emit,
  ) async {
    try {
      final cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .doc(event.dealUid)
          .collection('activities')
          .doc(event.activityUid)
          .delete();

      await DealService.addDealHistory(
        dealUid: event.dealUid,
        action: "Activity deleted",
      );
    } catch (e) {
      emit(DealError(e.toString()));
    }
  }
}