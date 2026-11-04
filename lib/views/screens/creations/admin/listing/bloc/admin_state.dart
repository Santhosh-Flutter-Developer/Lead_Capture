part of 'admin_bloc.dart';

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object> get props => [];
}

class AdminLoading extends AdminState {}

class AdminLoaded extends AdminState {
  final List<AdminModel> admins;

  const AdminLoaded(this.admins);

  @override
  List<Object> get props => [admins];
}

class AdminSuccess extends AdminState {
  final String message;
  const AdminSuccess(this.message);
}

class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);

  @override
  List<Object> get props => [message];
}
