part of 'backup_bloc.dart';

abstract class BackupEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchBackups extends BackupEvent {}

class StreamBackup extends BackupEvent {}
