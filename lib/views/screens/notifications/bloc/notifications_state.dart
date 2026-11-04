part of 'notifications_bloc.dart';

abstract class NotificationsState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class NotificationsInitial extends NotificationsState {}

// Loading state
class NotificationsLoading extends NotificationsState {}

// Loaded state with user list
class NotificationsLoaded extends NotificationsState {
  final List<NotificationModel> notification;
  NotificationsLoaded(this.notification);

  @override
  List<Object> get props => [notification];
}

// Error state
class NotificationsError extends NotificationsState {
  final String message;
  NotificationsError(this.message);

  @override
  List<Object> get props => [message];
}
