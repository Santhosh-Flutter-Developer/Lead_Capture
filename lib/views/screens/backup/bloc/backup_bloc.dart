import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'backup_event.dart';
part 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<BackupModel> allBackup = [];

  BackupBloc() : super(BackupLoading()) {
    on<StreamBackup>(_streamBackup);
  }

  Future<void> _streamBackup(
    StreamBackup event,
    Emitter<BackupState> emit,
  ) async {
    emit(BackupLoading());
    var cid = await Spdb.getCid();

    await emit.forEach(
      firestore
          .collection(Collections.backups.name)
          .where('parentCollectionId', isEqualTo: cid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            allBackup = snapshot.docs
                .map((doc) => BackupModel.fromMap(doc.data()))
                .toList();

            return allBackup;
          }),
      onData: (backup) => BackupLoaded(backup),
      onError: (error, stackTrace) {
        return BackupError("Failed to load backup, $error");
      },
    );
  }
}
