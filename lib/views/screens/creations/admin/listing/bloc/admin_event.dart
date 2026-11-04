part of 'admin_bloc.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class StreamAdmins extends AdminEvent {}

class AddAdmin extends AdminEvent {
  final AdminModel admin;
  const AddAdmin(this.admin);

  @override
  List<Object?> get props => [admin];
}

class UpdateAdmin extends AdminEvent {
  final String uid;
  final Map<String, dynamic> updatedData;
  const UpdateAdmin(this.uid, this.updatedData);

  @override
  List<Object?> get props => [uid, updatedData];
}

class DeleteAdmin extends AdminEvent {
  final String uid;
  const DeleteAdmin({required this.uid});

  @override
  List<Object?> get props => [uid];
}
