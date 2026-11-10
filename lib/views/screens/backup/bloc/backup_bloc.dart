import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'backup_event.dart';
part 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  List<BackupModel> allBackup = [];

  BackupBloc() : super(BackupLoading()) {
    on<StreamBackup>(_streamBackup);
  }

  /// The API has no backup listing, so this shows the snapshots created
  /// through settings.php `manual_backup` during this session.
  Future<void> _streamBackup(
    StreamBackup event,
    Emitter<BackupState> emit,
  ) async {
    allBackup = List.of(BackupTrigger.sessionBackups);
    emit(BackupLoaded(allBackup));
  }
}
