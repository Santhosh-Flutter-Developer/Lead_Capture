import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:leadcapture/services/database/src/download_history_store.dart';
import 'package:leadcapture/views/screens/download/bloc/download_event.dart';
import 'package:leadcapture/views/screens/download/bloc/download_state.dart';

class DownloadHistoryBloc
    extends Bloc<DownloadHistoryEvent, DownloadHistoryState> {
  DownloadHistoryBloc() : super(DownloadHistoryLoading()) {
    on<StreamDownloadHistory>(_onStream);
  }

  /// Local download log (SharedPreferences); reloads after each new download.
  Stream<List<DownloadHistoryModel>> _history() async* {
    yield await DownloadHistoryStore.load();
    final ctrl = StreamController<void>();
    void onChange() => ctrl.add(null);
    DownloadHistoryStore.changes.addListener(onChange);
    try {
      await for (final _ in ctrl.stream) {
        yield await DownloadHistoryStore.load();
      }
    } finally {
      DownloadHistoryStore.changes.removeListener(onChange);
      await ctrl.close();
    }
  }

  Future<void> _onStream(
    StreamDownloadHistory event,
    Emitter<DownloadHistoryState> emit,
  ) async {
    emit(DownloadHistoryLoading());
    await emit.forEach<List<DownloadHistoryModel>>(
      _history(),
      onData: (items) => DownloadHistoryLoaded(items),
      onError: (error, _) => DownloadHistoryError(error.toString()),
    );
  }
}
