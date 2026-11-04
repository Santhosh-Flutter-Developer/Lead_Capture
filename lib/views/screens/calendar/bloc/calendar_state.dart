part of 'calendar_bloc.dart';

abstract class CalendarState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class CalendarInitial extends CalendarState {}

// Loading state
class CalendarLoading extends CalendarState {}

// Loaded state with user list
class CalendarLoaded extends CalendarState {
  final List<EventModel> events;
  final List<TaskModel> tasks;
  final List<LeadModel> leads;
  final List<DealModel> deals;
  final List<CustomerTicketModel> tickets;
  CalendarLoaded(this.events, this.tasks, this.leads, this.deals, this.tickets);

  @override
  List<Object> get props => [events, tasks, leads, deals, tickets];
}

// Error state
class CalendarError extends CalendarState {
  final String message;
  CalendarError(this.message);

  @override
  List<Object> get props => [message];
}
