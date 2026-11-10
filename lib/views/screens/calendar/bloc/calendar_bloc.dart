import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'calendar_event.dart';
part 'calendar_state.dart';

/// Calendar BLoC – data comes from calendar.php (events) plus the migrated
/// task / lead / deal / ticket services, re-fetched after writes and polled.
class CalendarBloc extends Bloc<CalendarCalendar, CalendarState> {
  List<EventModel> allEvents = [];
  List<TaskModel> allTasks = [];
  List<LeadModel> allLeads = [];
  List<DealModel> allDeals = [];
  List<CustomerTicketModel> allTickets = [];

  CalendarBloc() : super(CalendarLoading()) {
    on<StreamCalendar>(_streamCalendar);
  }

  Future<void> _streamCalendar(
    StreamCalendar event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    final currentUser = await Spdb.getUser();
    final isAdmin = currentUser.userType == UserType.admin;

    // Admins see every record; employees only records they created.
    bool isRecordVisible(UserDataModel createdBy) =>
        isAdmin || createdBy.uid == currentUser.uid;
    // Events: only the creator sees them.
    bool isEventVisible(UserDataModel createdBy) => createdBy.uid == currentUser.uid;

    await emit.forEach<List<List<dynamic>>>(
      ApiLive.watch({'calendar', 'tasks', 'leads', 'deals', 'tickets'}, () async {
        final r = await Future.wait([
          EventService.getAllEvents(),
          TaskService.getAllTasks(),
          LeadService.getAllLeads(),
          DealService.getAllDeals(),
          TicketService.getAllTickets(),
        ]);
        return [
          (r[0] as List<EventModel>).where((e) => isEventVisible(e.createdBy)).toList(),
          (r[1] as List<TaskModel>).where((t) => isRecordVisible(t.taskCreatedBy)).toList(),
          (r[2] as List<LeadModel>).where((l) => isRecordVisible(l.createdBy)).toList(),
          (r[3] as List<DealModel>).where((d) => isRecordVisible(d.createdBy)).toList(),
          (r[4] as List<CustomerTicketModel>).where((t) => isRecordVisible(t.ticketCreatedBy)).toList(),
        ];
      }),
      onData: (d) => CalendarLoaded(
        allEvents = d[0] as List<EventModel>,
        allTasks = d[1] as List<TaskModel>,
        allLeads = d[2] as List<LeadModel>,
        allDeals = d[3] as List<DealModel>,
        allTickets = d[4] as List<CustomerTicketModel>,
      ),
      onError: (error, stackTrace) => CalendarError("Failed to load calendar: $error"),
    );
  }
}
