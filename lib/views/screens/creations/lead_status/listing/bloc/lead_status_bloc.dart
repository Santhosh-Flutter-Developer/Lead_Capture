import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_status_event.dart';
part 'lead_status_state.dart';

class LeadStatusBloc extends Bloc<LeadStatusEvent, LeadStatusState> {
  List<LeadStatusModel> allLeadStatus = [];

  LeadStatusBloc() : super(LeadStatusLoading()) {
    on<StreamLeadStatus>(_streamLeadStatus);
    on<DeleteLeadStatus>(_deleteLeadStatus);
  }

  Future<void> _streamLeadStatus(
    StreamLeadStatus event,
    Emitter<LeadStatusState> emit,
  ) async {
    emit(LeadStatusLoading());
    await emit.forEach(
      ApiLive.watch({'lead_status'}, () async {
        allLeadStatus = await LeadStatusService.getAllLeadStatus();
        allLeadStatus.sort((a, b) => b.orderNumber.compareTo(a.orderNumber));
        return allLeadStatus;
      }),
      onData: (leadStatus) => LeadStatusLoaded(leadStatus),
      onError: (error, stackTrace) {
        return LeadStatusError("Failed to load leadStatus, $error");
      },
    );
  }

  Future<void> _deleteLeadStatus(
    DeleteLeadStatus event,
    Emitter<LeadStatusState> emit,
  ) async {
    try {
      await LeadStatusService.deleteLeadStatus(uid: event.uid);

      var updatedList = await LeadStatusService.getAllLeadStatus();
      emit(LeadStatusLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadStatusError("Failed to delete leadStatus: $e"));
    }
  }
}
