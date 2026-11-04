import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class PostNotificationService {
  static FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> _getAccessToken() async {
    try {
      final tokenDoc = await firebase.system.doc('serviceToken').get();

      if (tokenDoc.exists) {
        final data = tokenDoc.data()!;
        final expiry = DateTime.fromMillisecondsSinceEpoch(data['expiry']);
        if (DateTime.now().isBefore(
          expiry.subtract(const Duration(minutes: 5)),
        )) {
          debugPrint("Using cached token from Firestore");
          return data['token'];
        }
      }

      var serviceAccountDoc = await firebase.system.doc('serviceAccount').get();
      if (!serviceAccountDoc.exists || serviceAccountDoc.data() == null) {
        debugPrint("Service account document not found or empty");
        return null;
      }
      var serviceAccount = serviceAccountDoc.data()!['account'];

      // otherwise generate new one
      final serviceAccountJson = json.decode(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final credentials = auth.ServiceAccountCredentials.fromJson(
        serviceAccountJson,
      );
      final client = await auth.clientViaServiceAccount(credentials, scopes);

      final newToken = client.credentials.accessToken.data;
      final expiry = client.credentials.accessToken.expiry;
      client.close();

      await firebase.system.doc('serviceToken').set({
        'token': newToken,
        'expiry': expiry.millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint("New token generated and saved");
      return newToken;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Token error: $e\n$st");
      return null;
    }
  }

  static Future<void> sendNotification({
    required NotificationModel model,
  }) async {
    try {
      final String? serverKey = await _getAccessToken();

      debugPrint(
        '📤 [PUSH] serverKey=${serverKey != null}, tokens=${model.toFcms.length}, type=${model.type?.name}',
      );
      // Try to send push notification if server key is available
      if (serverKey != null && model.toFcms.isNotEmpty) {
        String endpointFirebaseCloudMessaging =
            "https://fcm.googleapis.com/v1/projects/leadcapture-79a43/messages:send";

        for (var element in model.toFcms) {
          // Deliberately data-only (no top-level "notification" field) — a
          // "notification" field makes Android/iOS auto-display it in the
          // system tray *in addition to* the local notification the app's
          // own background handler shows, producing two banners for the
          // same push. showNotification() in notification_service.dart
          // already falls back to data['title']/data['body'].
          final Map<String, dynamic> message = {
            "message": {
              "android": {"priority": "high"},
              "apns": {
                "headers": {"apns-priority": "10"},
                "payload": {
                  "aps": {"content-available": 1},
                },
              },
              "token": element,
              "data": {
                ...model.payload.map((k, v) => MapEntry(k, v.toString())),
                "title": model.title,
                "body": model.body,
                "type": model.type?.name,
                // Intended recipients. The receiving app drops the push if
                // the logged-in user is not in this list (FCM data payload
                // is limited to 4KB, so skip it for very large groups).
                if (model.toUids.isNotEmpty &&
                    model.toUids.join(',').length <= 800)
                  "toUids": model.toUids.join(','),
              },
            },
          };

          try {
            final http.Response response = await http.post(
              Uri.parse(endpointFirebaseCloudMessaging),
              headers: {
                'Authorization': 'Bearer $serverKey',
                'Content-Type': 'application/json',
              },
              body: json.encode(message),
            );

            if (response.statusCode == 200) {
              debugPrint('✅ [PUSH] sent OK: ${response.body}');
            } else {
              // Token is dead (app uninstalled / expired): stop using it.
              if (response.body.contains('UNREGISTERED') ||
                  response.statusCode == 404) {
                await AuthService.removeFcmTokenEverywhere(element);
              }
              debugPrint(
                '❌ [PUSH] FCM rejected (${response.statusCode}) for token '
                '${element.substring(0, element.length > 12 ? 12 : element.length)}…: ${response.body}',
              );
            }
          } catch (e) {
            debugPrint("Push notification failed for token $element: $e");
            // Continue with other tokens even if one fails
          }
        }
      } else if (serverKey == null) {
        debugPrint(
          "Push notification skipped: server key not available (service account missing)",
        );
      }

      // Always store notification in database
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.notifications.name}',
        model.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }
}