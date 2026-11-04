import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/constants/constants.dart';
part 'tickets_event.dart';
part 'tickets_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<CustomerTicketModel> allTickets = [];

  TicketBloc() : super(TicketLoading()) {
    on<StreamTickets>(_streamTickets);
    on<DeleteTicket>(_deleteTicket);
  }

  Future<void> _streamTickets(StreamTickets event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    try {
      final uid = await Spdb.getUid();
      final cid = await Spdb.getCid();

      final query = firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .where(
            Filter.or(
              Filter('assignTo', arrayContains: uid),
              Filter('createdBy', arrayContains: uid),
              Filter('observers', arrayContains: uid),
              Filter('participants', arrayContains: uid),
            ),
          )
          .orderBy('createdAt', descending: true);

      await emit.forEach<List<CustomerTicketModel>>(
        query.snapshots().map((snapshot) {
          allTickets = snapshot.docs
              .map((doc) => CustomerTicketModel.fromMap(doc.id, doc.data()))
              .toList();
          return allTickets;
        }),
        onData: (tickets) => TicketLoaded(tickets),
        onError: (e, st) {
          return TicketError("Failed to load tickets: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TicketError("Error streaming tickets: $e"));
    }
  }

  Future<void> _deleteTicket(DeleteTicket event, Emitter<TicketState> emit) async {
    try {
      emit(TicketDeleting());
      await TicketService.deleteTicket(uid: event.uid);
      emit(TicketDeleted());
      add(StreamTickets());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TicketError("Failed to delete ticket: $e"));
    }
  }
}

class TicketHistoryBloc extends Bloc<TicketHistoryEvent, TicketHistoryState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<TicketHistoryModel> allTickets = [];

  TicketHistoryBloc() : super(TicketHistoryLoading()) {
    on<StreamTicketHistory>(_streamTicketHistory);
  }

  Future<void> _streamTicketHistory(
    StreamTicketHistory event,
    Emitter<TicketHistoryState> emit,
  ) async {
    emit(TicketHistoryLoading());
    try {
      final cid = await Spdb.getCid();

      await emit.forEach<List<TicketHistoryModel>>(
        firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.customerTickets.name)
            .doc(event.uid)
            .collection(Collections.ticketHistory.name)
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              allTickets = snapshot.docs
                  .map((doc) => TicketHistoryModel.fromMap(doc.data()))
                  .toList();
              return allTickets;
            }),
        onData: (tickets) => TicketHistoryLoaded(tickets),
        onError: (e, st) {
          debugPrint(st.toString());
          return TicketHistoryError("Failed to load tickets: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      emit(TicketHistoryError("Error streaming tickets: $e"));
    }
  }
}

class TicketCommentsBloc extends Bloc<TicketCommentsEvent, TicketCommentsState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<TicketCommentModel> allTickets = [];

  TicketCommentsBloc() : super(TicketCommentsLoading()) {
    on<StreamTicketComments>(_streamTicketComment);
  }

  Future<void> _streamTicketComment(
    StreamTicketComments event,
    Emitter<TicketCommentsState> emit,
  ) async {
    emit(TicketCommentsLoading());
    try {
      final cid = await Spdb.getCid();

      await emit.forEach<List<TicketCommentModel>>(
        firestore
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.customerTickets.name)
            .doc(event.uid)
            .collection(Collections.ticketComments.name)
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              allTickets = snapshot.docs
                  .map((doc) => TicketCommentModel.fromMap(doc.data()))
                  .toList();
              return allTickets;
            }),
        onData: (tickets) => TicketCommentsLoaded(tickets),
        onError: (e, st) {
          debugPrint(st.toString());
          return TicketCommentsError("Failed to load tickets: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      emit(TicketCommentsError("Error streaming tickets: $e"));
    }
  }
}
