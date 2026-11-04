part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchNotificationss extends NotificationsEvent {}

class StreamNotifications extends NotificationsEvent {}

// notifications_event.dart
class DeleteNotifications extends NotificationsEvent {
  final String notificationId;

  DeleteNotifications({required this.notificationId});

  @override
  List<Object> get props => [notificationId];
}

class RestoreNotification extends NotificationsEvent {
  final NotificationModel notification;

  RestoreNotification({required this.notification});
}
