part of 'tickets_bloc.dart';

abstract class TicketState extends Equatable {
  const TicketState();

  @override
  List<Object?> get props => [];
}

class TicketLoading extends TicketState {}

class TicketLoaded extends TicketState {
  final List<CustomerTicketModel> tickets;

  const TicketLoaded(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

class TicketDeleting extends TicketState {}

class TicketDeleted extends TicketState {}

class TicketError extends TicketState {
  final String message;

  const TicketError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class TicketHistoryState extends Equatable {
  const TicketHistoryState();

  @override
  List<Object?> get props => [];
}

class TicketHistoryLoading extends TicketHistoryState {}

class TicketHistoryLoaded extends TicketHistoryState {
  final List<TicketHistoryModel> ticketHistory;

  const TicketHistoryLoaded(this.ticketHistory);

  @override
  List<Object?> get props => [ticketHistory];
}

class TicketHistoryError extends TicketHistoryState {
  final String message;

  const TicketHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class TicketCommentsState extends Equatable {
  const TicketCommentsState();

  @override
  List<Object?> get props => [];
}

class TicketCommentsLoading extends TicketCommentsState {}

class TicketCommentsLoaded extends TicketCommentsState {
  final List<TicketCommentModel> ticketComments;

  const TicketCommentsLoaded(this.ticketComments);

  @override
  List<Object?> get props => [ticketComments];
}

class TicketCommentsError extends TicketCommentsState {
  final String message;

  const TicketCommentsError(this.message);

  @override
  List<Object?> get props => [message];
}
