part of 'calendar_bloc.dart';

abstract class CalendarCalendar extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchCalendars extends CalendarCalendar {}

class StreamCalendar extends CalendarCalendar {}
