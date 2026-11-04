part of 'backup_bloc.dart';

abstract class BackupState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class BackupInitial extends BackupState {}

// Loading state
class BackupLoading extends BackupState {}

// Loaded state with user list
class BackupLoaded extends BackupState {
  final List<BackupModel> backups;
  BackupLoaded(this.backups);

  @override
  List<Object> get props => [backups];
}

// Error state
class BackupError extends BackupState {
  final String message;
  BackupError(this.message);

  @override
  List<Object> get props => [message];
}
