# Flutter ↔ PHP API mapping

Base URL (central: `lib/services/api/src/api_config.dart`): production `https://sriseosolutions.com/mahendran/crm_php/api`, local `http://localhost/mahendran/leadcapture_crm/crm_php/api`. Envelope `{status,message,data}` (HTTP 200 can still be a failure → `ensureSuccess()`), `action` in body/query, `Authorization: Bearer <uid>`.

| App module | Flutter service / bloc | PHP file · actions used |
|---|---|---|
| Login, logout, forgot/reset password, change password, register | `AuthService`, login/forgot/company_registration screens | `auth.php` |
| Employees, admins, my profile | `EmployeeService`, `AdminService`, profile screens | `employees.php` (list/get/create/update/delete/restore/toggle_status/bulk_*/get_my_profile/update_my_profile/remove_my_avatar/check_assigned) |
| Roles / designations / departments / sub-departments | `*Service`, `*Bloc` | `roles.php`, `designations.php`, `departments.php`, `sub_departments.php` |
| Lead category/source/priority/status, deal status, payment mode, holidays | master services + blocs | `masters.php` (type per master) |
| Leads (+comments, history, activity, attachments) | `LeadService`, `LeadBloc` | `leads.php` |
| Deals | `DealService`, `DealBloc` | `deals.php` |
| Tasks | `TaskService`, `TaskBloc` | `tasks.php` |
| Tickets | `TicketService`, `TicketBloc` | `tickets.php` |
| Projects, project updations | `ProjectService`, `ProjectUpdationService` | `projects.php`, `project_updations.php` |
| Payments | `PaymentService` | `payments.php` |
| Clients, master companies | `ClientService`, `MasterCompanyService` | `master_clients.php`, `master_companies.php` |
| Notifications | `NotificationService`, `NotificationsBloc`, desktop poller | `notifications.php` |
| Calendar / events | `EventService`, `CalendarBloc` | `calendar.php` |
| Dashboard | `DashboardService` | `dashboard.php overview` (+ task/ticket/event/notification lists) |
| Activity log, login log | `ActivityLogsBloc`, `LoginLogsBloc` | `logs.php` (`activity`, `login`) |
| Settings, trash, backup | `SettingsService`, `TrashScreen`, `BackupTrigger` | `settings.php` (get, update_preference, trash_list, trash_restore, manual_backup …) |
| Chat | `ChatService`, `ChatBloc` | `chats.php` (threads, messages, send_message, create_direct/group, group_members, update_group, react_message, edit/delete_message, toggle_pin(_message), toggle_favorite, forward_message, delete/restore/clear_chat, leave_group, user_profile) |
| Feed | `FeedService`, feed blocs | `feed.php` |
| Countries/states/districts/cities | `RegionService` | `locations.php` |
| App version | `VersionService` | `settings.php get → version` |
| File upload | `StorageService` | `upload.php` |

Notes: uid strings ↔ integer ids are bridged by `ApiLookup`; colors `#RRGGBB` ↔ ARGB ints by `ApiMappers`; the server writes history/notifications/activity logs itself, so client calls for those are no-ops; the server auto-converts a lead to a deal on final status.
