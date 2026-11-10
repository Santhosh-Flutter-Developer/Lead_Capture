import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'designation_event.dart';
part 'designation_state.dart';

class DesignationBloc extends Bloc<DesignationEvent, DesignationState> {
  List<DesignationModel> allDesignations = [];

  DesignationBloc() : super(DesignationLoading()) {
    on<StreamDesignation>(_stream);
  }

  /// PHP API has no realtime channel: data is re-fetched after every write
  /// (ApiLive.changed) and polled every 30s for changes by other users.
  Future<void> _stream(StreamDesignation event, Emitter<DesignationState> emit) async {
    emit(DesignationLoading());
    await emit.forEach<List<DesignationModel>>(
      ApiLive.watch({'designation'}, () async {
        allDesignations = await DesignationService.getAllDesignations();
        return allDesignations;
      }),
      onData: (items) => DesignationLoaded(items),
      onError: (error, stackTrace) =>
          DesignationError("Failed to load designation, $error"),
    );
  }
}
