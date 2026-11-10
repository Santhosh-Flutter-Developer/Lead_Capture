import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';
part 'tickets_event.dart';
part 'tickets_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  List<CustomerTicketModel> allTickets = [];

  TicketBloc() : super(TicketLoading()) {
    on<StreamTickets>(_streamTickets);
    on<DeleteTicket>(_deleteTicket);
  }

  Future<void> _streamTickets(StreamTickets event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    try {
      await emit.forEach<List<CustomerTicketModel>>(
        ApiLive.watch({'tickets'}, () async => allTickets = await TicketService.getMyTickets()),
        onData: (tickets) => TicketLoaded(tickets),
        onError: (e, st) => TicketError("Failed to load tickets: $e"),
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
  TicketHistoryBloc() : super(TicketHistoryLoading()) {
    on<StreamTicketHistory>(_streamTicketHistory);
  }

  Future<void> _streamTicketHistory(
    StreamTicketHistory event,
    Emitter<TicketHistoryState> emit,
  ) async {
    emit(TicketHistoryLoading());
    // tickets.php has no history table (see MISSING_API_REQUIREMENTS.md).
    emit(TicketHistoryLoaded(const []));
  }
}

class TicketCommentsBloc extends Bloc<TicketCommentsEvent, TicketCommentsState> {
  TicketCommentsBloc() : super(TicketCommentsLoading()) {
    on<StreamTicketComments>(_streamTicketComment);
  }

  Future<void> _streamTicketComment(
    StreamTicketComments event,
    Emitter<TicketCommentsState> emit,
  ) async {
    emit(TicketCommentsLoading());
    try {
      await emit.forEach<List<TicketCommentModel>>(
        TicketService.streamComments(cid: '', ticketId: event.uid),
        onData: (c) => TicketCommentsLoaded(c),
        onError: (e, st) {
          debugPrint(st.toString());
          return TicketCommentsError("Failed to load comments: $e");
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(TicketCommentsError("Error streaming comments: $e"));
    }
  }
}
