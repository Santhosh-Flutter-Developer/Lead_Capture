// ─────────────────────────────────────────────────────────────────────────────
// firebase-messaging-sw.js  — NEW FILE  (place in /web folder)
//
// This service worker is required for Firebase Cloud Messaging background
// push notifications on web. It runs in the background even when the browser
// tab is closed.
//
// HOW TO GET YOUR VAPID KEY:
//   1. Go to Firebase Console → Project Settings
//   2. Click "Cloud Messaging" tab
//   3. Scroll to "Web Push certificates"
//   4. Click "Generate key pair" (or use existing)
//   5. Copy the Key Pair string and paste it into notification_service.dart
//      as kVapidKey
//
// This file uses the Firebase compat SDK (v9 compat) which works in SW context.
// ─────────────────────────────────────────────────────────────────────────────

// ── Lifecycle: always run the newest worker immediately ──────────────────────
// Without this, a cached older copy of this file can keep handling clicks
// after an update, and the new click handler never runs.
var SW_VERSION = 'lc-sw-v5';

// Sends a status line to the page (printed in the `flutter run` console by
// diagnoseServiceWorker in notification_service_web.dart).
function report(stage, extra) {
  try {
    var ch = new BroadcastChannel('lc_sw_info');
    ch.postMessage({ type: 'lc-sw-debug', version: SW_VERSION, stage: stage, extra: extra || null });
    ch.close();
  } catch (e) {}
}
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// Lets the page ask "which worker version is running?" (see the web
// diagnostics in notification_service_web.dart). Answers over BroadcastChannel,
// which works even if the page's service-worker message queue isn't started.
self.addEventListener('message', function (event) {
  if (event.data && event.data.type === 'lc-ping') {
    try {
      var bc = new BroadcastChannel('lc_sw_info');
      bc.postMessage({ type: 'lc-pong', version: SW_VERSION });
      bc.close();
    } catch (e) {}
  }
});

// ── Notification click handler ────────────────────────────────────────────────
// Registered BEFORE firebase is loaded so it always runs first.
// Focuses the existing app tab (and tells it which chat to open through a
// BroadcastChannel), or opens a new tab straight at the chat.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  var data = event.notification.data || {};
  var isChat = data.type === 'chat' && data.chatId;
  // Open under the app's own base path (the registration scope, e.g.
  // /shanmugam/leadcapture/), not the site root.
  var base = (self.registration && self.registration.scope) ? self.registration.scope : '/';
  var target = isChat
    ? base + '?notifType=chat&chatId=' + encodeURIComponent(data.chatId)
    : base;
  console.log('[SW ' + SW_VERSION + '] notificationclick', data, '->', target);
  report('notificationclick fired', { type: data.type, chatId: data.chatId, target: target });

  function openNew() {
    return self.clients.openWindow ? self.clients.openWindow(target) : null;
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (windowClients) {
        console.log('[SW ' + SW_VERSION + '] open tabs:', windowClients.length);
        report('tabs found', windowClients.map(function (c) { return c.url; }));
        for (var i = 0; i < windowClients.length; i++) {
          var client = windowClients[i];
          if ('focus' in client) {
            if (isChat) {
              try {
                var bc = new BroadcastChannel('lc_notif_click');
                bc.postMessage({ type: 'chat', chatId: data.chatId });
                bc.close();
                report('chat broadcast sent', data.chatId);
              } catch (e) {
                console.log('[SW] broadcast failed', e);
                report('broadcast failed', String(e));
              }
            }
            // client.navigate() is deliberately NOT used: it rejects for tabs
            // this worker does not control (every tab here).
            return client.focus().then(function () {
              report('focus ok');
            }).catch(function (e) {
              console.log('[SW] focus failed, opening a new tab', e);
              report('focus failed', String(e));
              return openNew();
            });
          }
        }
        report('no open tab, opening a new one', target);
        return openNew();
      })
      .catch(function (e) {
        console.log('[SW ' + SW_VERSION + '] notificationclick failed', e);
        report('notificationclick failed', String(e));
        return openNew();
      })
  );
});

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// ── Firebase config (matches firebase_options.dart web config) ────────────────
firebase.initializeApp({
  apiKey: 'AIzaSyDKmsjoWTQS7rk-56HaWQ9FI7KYMocoCKU',
  authDomain: 'leadcapture-79a43.firebaseapp.com',
  projectId: 'leadcapture-79a43',
  storageBucket: 'leadcapture-79a43.firebasestorage.app',
  messagingSenderId: '884184513529',
  appId: '1:884184513529:web:46707c8332034373995b28',
});

const messaging = firebase.messaging();

// ── Background message handler ────────────────────────────────────────────────
// This fires when a push message arrives while the app tab is in the background
// or the browser is closed. It shows a system notification.
messaging.onBackgroundMessage(function (payload) {
  console.log('[SW ' + SW_VERSION + '] Background message received:', payload);
  report('push shown by this worker', payload && payload.data ? { type: payload.data.type, chatId: payload.data.chatId } : null);

  const notificationTitle =
    payload.notification?.title ||
    payload.data?.title ||
    'LeadcaptureCRM';

  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'New notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
    // Vibrate pattern for mobile browsers that support it
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions,
  );
});