part of 'tickets_bloc.dart';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

class StreamTickets extends TicketEvent {}

class DeleteTicket extends TicketEvent {
  final String uid;
  const DeleteTicket(this.uid);
  @override
  List<Object?> get props => [uid];
}

abstract class TicketHistoryEvent extends Equatable {
  const TicketHistoryEvent();

  @override
  List<Object?> get props => [];
}

class StreamTicketHistory extends TicketHistoryEvent {
  final String uid;
  const StreamTicketHistory(this.uid);
  @override
  List<Object?> get props => [uid];
}

abstract class TicketCommentsEvent extends Equatable {
  const TicketCommentsEvent();

  @override
  List<Object?> get props => [];
}

class StreamTicketComments extends TicketCommentsEvent {
  final String uid;
  const StreamTicketComments(this.uid);
  @override
  List<Object?> get props => [uid];
}
