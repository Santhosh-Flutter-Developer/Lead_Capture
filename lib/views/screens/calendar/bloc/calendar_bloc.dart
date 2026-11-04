import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarCalendar, CalendarState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
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

    final cid = await Spdb.getCid();
    final currentUser = await Spdb.getUser();
    final isAdmin = currentUser.userType == UserType.admin;

    await LeadService.backfillLeadActivitiesToCalendar();

    // Visibility rule for tasks/leads/deals/tickets:
    //  - Admin logins can see every record, whether it was created by an
    //    admin or by an employee.
    //  - An employee login can only see records that they themselves
    //    created (records created by an admin, or by other employees,
    //    stay hidden from them).
    bool isRecordVisible(UserDataModel createdBy) {
      if (isAdmin) return true;
      return createdBy.uid == currentUser.uid;
    }

    // Visibility rule for events: only the person who created the event
    // (admin or employee) can see it — never anyone else, admin included.
    bool isEventVisible(UserDataModel createdBy) {
      return createdBy.uid == currentUser.uid;
    }

    final eventsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.events.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => EventModel.fromMap(d.id, d.data()))
              .where((e) => isEventVisible(e.createdBy))
              .toList(),
        );

    final tasksStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => TaskModel.fromMap(d.id, d.data()))
              .where((t) => isRecordVisible(t.taskCreatedBy))
              .toList(),
        );

    final leadsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => LeadModel.fromMap(d.id, d.data()))
              .where((l) => isRecordVisible(l.createdBy))
              .toList(),
        );

    final dealsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => DealModel.fromMap(d.id, d.data()))
              .where((d) => isRecordVisible(d.createdBy))
              .toList(),
        );

    final ticketsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => CustomerTicketModel.fromMap(d.id, d.data()))
              .where((t) => isRecordVisible(t.ticketCreatedBy))
              .toList(),
        );

    await emit.forEach(
      Rx.combineLatest5<
        List<EventModel>,
        List<TaskModel>,
        List<LeadModel>,
        List<DealModel>,
        List<CustomerTicketModel>,
        Map<String, dynamic>
      >(
        eventsStream,
        tasksStream,
        leadsStream,
        dealsStream,
        ticketsStream,
        (events, tasks, leads, deals, tickets) => {'events': events, 'tasks': tasks, 'leads': leads, 'deals': deals, 'tickets': tickets},
      ),
      onData: (data) {
        return CalendarLoaded(
          data['events'] as List<EventModel>,
          data['tasks'] as List<TaskModel>,
          data['leads'] as List<LeadModel>,
          data['deals'] as List<DealModel>,
          data['tickets'] as List<CustomerTicketModel>,
        );
      },
      onError: (error, stackTrace) {
        return CalendarError("Failed to load calendar: $error");
      },
    );
  }
}
