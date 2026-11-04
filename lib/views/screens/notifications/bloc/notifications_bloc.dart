import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
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
    var cid = await Spdb.getCid();
    var uid = await Spdb.getUid();

    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.notifications.name)
          .where('toUids', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            allNotifications = snapshot.docs
                .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
                .toList();

            // The user has this screen open, so everything listed here is
            // "seen": mark the unread ones as read so the header badge
            // count drops to 0. After the write, the snapshot fires again
            // with readBy updated -> nothing left to mark -> no loop.
            final unreadIds = allNotifications
                .where(
                  (n) =>
                      n.uid != null &&
                      uid != null &&
                      !n.readBy.contains(uid),
                )
                .map((n) => n.uid!)
                .toList();
            if (unreadIds.isNotEmpty) {
              markNotificationsAsRead(unreadIds);
            }

            return allNotifications;
          }),
      onData: (notifications) => NotificationsLoaded(notifications),
      onError: (error, stackTrace) {
        return NotificationsError("Failed to load notifications, $error");
      },
    );
  }

  Future<void> _deleteNotifications(
    DeleteNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      var cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.notifications.name)
          .doc(event.notificationId)
          .delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(NotificationsError("Failed to delete notification: $e"));
    }
  }

  Future<void> _restoreNotification(
    RestoreNotification event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      var cid = await Spdb.getCid();

      await firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.notifications.name)
          .doc(event.notification.uid)
          .set(event.notification.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }
}