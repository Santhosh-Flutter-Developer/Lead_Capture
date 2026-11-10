import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_priority_event.dart';
part 'lead_priority_state.dart';

class LeadPriorityBloc extends Bloc<LeadPriorityEvent, LeadPriorityState> {
  List<LeadPriorityModel> allLeadPriority = [];

  LeadPriorityBloc() : super(LeadPriorityLoading()) {
    on<StreamLeadPriority>(_streamLeadPriority);
    on<DeleteLeadPriority>(_deleteLeadPriority);
  }

  Future<void> _streamLeadPriority(
    StreamLeadPriority event,
    Emitter<LeadPriorityState> emit,
  ) async {
    emit(LeadPriorityLoading());
    await emit.forEach(
      ApiLive.watch({'lead_priority'}, () async {
        allLeadPriority = await LeadPriorityService.getAllLeadPriority();
        return allLeadPriority;
      }),
      onData: (leadPriority) => LeadPriorityLoaded(leadPriority),
      onError: (error, stackTrace) {
        return LeadPriorityError("Failed to load leadPriority, $error");
      },
    );
  }

  Future<void> _deleteLeadPriority(
    DeleteLeadPriority event,
    Emitter<LeadPriorityState> emit,
  ) async {
    try {
      await LeadPriorityService.deleteLeadPriority(uid: event.uid);

      var updatedList = await LeadPriorityService.getAllLeadPriority();
      emit(LeadPriorityLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadPriorityError("Failed to delete leadPriority: $e"));
    }
  }
}
