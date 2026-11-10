# Missing / insufficient API (found while integrating against the PHP source)

Nothing below was invented on the client; in the UI these actions show a clear "not supported by the server API" message or are no-ops.

## Needed for full parity
1. **FCM / device token registration** (register, remove, list per user) – push notifications cannot be fully migrated without it (FCM is still used).
2. **Realtime** (WebSocket/SSE) or `since`/`after_id` on `chats.php`, `notifications.php` – polling is used today.
3. **Chat:** typing indicator, threads, per-user "delete for me", group description, presence setter (`is_online` is server-side only).
4. **Leads/Deals:** edit/delete of lead/deal activities, edit comments; extra lead fields the table lacks (company website/country/state/city/zip, client email/gender); workflow history is synthesized.
5. **Tasks/Tickets:** history list, time-log writes, `delete_attachment` for tasks/tickets/payments.
6. **Restore** for deals, tasks, tickets, projects, updations, payments, masters (only leads, clients, employees and settings trash restore exist).
7. **Files:** delete-file endpoint (`StorageService.deleteImage` cannot delete).
8. **Clients:** send-email endpoint (client email sending is disabled; SMTP secret removed from the app).
9. **Employees:** `update` cannot change `user_type`, so Admin ⇄ Employee conversion of an existing user is blocked in the form; reporting_to update.
10. **Backup:** list/download/delete/import (only `manual_backup` exists; list shows backups made in the current session).
11. **Events:** completed flag; mirroring lead activities into the calendar.
12. **Reminders** and **error-log reporting** endpoints (now no-op / local log).
13. **Legacy kiosk/companies module** (`CompanyService` other than the registration check).
14. Pagination parameters on list endpoints (UI filters client-side).

## Security
* Token is the plain user uid (not signed/expiring) – recommend real expiring tokens.
* Rotate: SMTP password, FCM service-account key, admin password from the Postman env.

## Deployment
The PHP files `require` `config/` and `includes/` which were not in the zip – the server needs them (tested only by reading code).
