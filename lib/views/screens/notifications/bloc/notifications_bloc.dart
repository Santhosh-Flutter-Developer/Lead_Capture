import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  List<NotificationModel> allNotifications = [];

  NotificationsBloc() : super(NotificationsLoading()) {
    on<StreamNotifications>(_streamNotifications);
    on<DeleteNotifications>(_deleteNotifications);
    on<RestoreNotification>(_restoreNotification);
  }

  Future<void> _streamNotifications(
    StreamNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(NotificationsLoading());
    final uid = await Spdb.getUid();

    await emit.forEach<List<NotificationModel>>(
      ApiLive.watch({'notifications'}, () async {
        final res = (await NotificationsApiService.call('list')).ensureSuccess();
        allNotifications = Js.mapList(res.dataMap['notifications'])
            .map((m) => CrmMappers.notification(m, myUid: uid))
            .toList();

        // The screen is open, so everything listed is "seen": mark unread ones.
        final unreadIds = allNotifications
            .where((n) => n.uid != null && uid != null && !n.readBy.contains(uid))
            .map((n) => n.uid!)
            .toList();
        if (unreadIds.isNotEmpty) {
          markNotificationsAsRead(unreadIds);
        }
        return allNotifications;
      }),
      onData: (notifications) => NotificationsLoaded(notifications),
      onError: (error, stackTrace) =>
          NotificationsError("Failed to load notifications, $error"),
    );
  }

  Future<void> _deleteNotifications(
    DeleteNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await deleteNotification(event.notificationId);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(NotificationsError("Failed to delete notification: $e"));
    }
  }

  Future<void> _restoreNotification(
    RestoreNotification event,
    Emitter<NotificationsState> emit,
  ) async {
    await restoreNotification(event.notification);
  }
}
