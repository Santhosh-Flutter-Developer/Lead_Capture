# Firebase → PHP API migration analysis (LeadCapture CRM)

Source of truth: the PHP files in `api_7.zip` (not the docs). PHP was not modified.

## What was replaced
| Firebase use | Replacement |
|---|---|
| Firebase Auth / custom login | `auth.php` (login, logout, OTP forgot/reset, change password, register) + `SessionManager`/`Spdb` (Bearer token = user uid) |
| Firestore collections (users, employees, admins, roles, designations, departments, leads, deals, tasks, tickets, projects, updations, payments, clients, notifications, events, chat, feed, holidays, logs, settings, trash, backup) | The matching `*.php` module through `lib/services/api/src/*` wrappers + mappers |
| Firestore snapshot streams | Polling `ApiLive.watch` (30 s default, 5 s open chat, immediate refetch after any local change) |
| Firebase Storage | `upload.php` (`StorageService`, `ApiAttachments` url→id registry) |
| Cloud Functions mail / reminders | Server side (no client call) |
| Firestore offline cache | Hive `CacheService`, now filled from the API services |
| Firestore `errors`, `download_history` | Local on-device logs (no API exists) |
| Dashboard aggregation | `dashboard.php overview` + migrated services |

## Kept on purpose
`firebase_core` + `firebase_messaging` (FCM push only) — the PHP API has no push/device-token endpoint. `cloud_firestore` and `firebase_storage` were removed from `pubspec.yaml`.

## Removed from the Flutter app (not in PHP, per your decision)
Attendance, work time, work-from-home, leave requests, salary, bank details, employee status.

## Security findings (action needed)
* A hardcoded SMTP password and an FCM service-account private key were in client code. Both were removed from code, but **must be rotated** (they were exposed in the repo history).
* Your Postman environment contains a real admin password – rotate it and do not share it.
