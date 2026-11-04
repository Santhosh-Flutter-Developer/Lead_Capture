# LeadCapture Project Analysis Report

## 1) Scope and Method

This report is based on direct analysis of the Flutter codebase in this workspace.
It covers:
- Application architecture and runtime flow
- Functional modules and ownership in code
- Database and storage architecture (cloud + local)
- Authentication/session/security implementation
- Screen-level inventory and module-wise UI coverage
- Observed technical risks and improvement opportunities

Primary references:
- lib/main.dart
- lib/app/src/app.dart
- lib/app/src/auth_provider.dart
- lib/constants/src/enum.dart
- lib/services/firebase/src/*.dart
- lib/services/database/src/*.dart
- lib/models/src/*.dart
- lib/views/screens/**/*.dart
- pubspec.yaml
- lib/firebase_options.dart

---

## 2) Executive Summary

LeadCapture is a multi-platform Flutter CRM application built around Firebase (Firestore + Storage + Messaging) with local caching via Hive and SharedPreferences.

Current implementation pattern:
- Multi-tenant Firestore data model anchored at users/{companyId}
- Service-driven data access (43 Firebase service files)
- Local cache for master/reference data with periodic sync (6-hour timer)
- Screen-heavy modular UI with BLoC in many listing screens
- Desktop/mobile branching in main shell and runtime checks for Windows

Inventory totals from this workspace:
- Screen code files: 231
- Firebase service files: 43
- Database service files: 3
- Model files: 42

---

## 3) Runtime and Architecture

### 3.1 App bootstrap flow

From main.dart:
1. Firebase initializes using DefaultFirebaseOptions.currentPlatform
2. Firestore offline persistence is enabled with unlimited cache size
3. Desktop path initializes local notifications and Firestore notification listener
4. CacheService initializes Hive boxes and sync timer
5. Version service initializes
6. Session/panel settings are loaded from SharedPreferences
7. If user session exists, lifecycle observer marks user online/offline

### 3.2 State management and shell

From app.dart and auth_provider.dart:
- Provider is used globally with:
  - AuthProvider
  - ThemeProvider
  - MessageProvider
- AuthProvider selects the initial home widget based on:
  - Login state
  - Required app update state
  - Windows runtime installation state
- Main shell branches by platform:
  - MobileMainScreen for mobile
  - DesktopMainScreen for desktop

### 3.3 Navigation model

- Route helper utilities are used (push/replace style)
- Desktop side menu drives feature-level navigation
- RouteScreen acts as a desktop landing workspace layer before dashboard navigation

---

## 4) Functional Module Map

The project is organized by features in lib/views/screens and mirrored by service/model layers.

### 4.1 Core CRM modules

- Authentication and account onboarding
  - auth/login/reset/change initial password/company registration
  - Services: auth_service
  - Models: admin_model, employee_model, user_model, user_data_model, device_model

- Leads
  - listing, kanban, calendar, create/edit/view, upload, charts
  - Services: lead_service, lead_status_service, lead_source_service, lead_category_service, lead_priority_service
  - Models: lead_model, lead_status_model, lead_source_model, lead_category_model, lead_priority_model

- Deals
  - listing, kanban, calendar/timeline, create/edit/view
  - Services: deal_service, deal_status_service
  - Models: deal_model, deal_status_model

- Clients
  - company/contact listing, create/edit/profile
  - Services: client_service
  - Models: client_model

- Tasks
  - listing, calendar/status visuals, create/edit/view
  - Services: task_service
  - Models: task_model

- Projects
  - listing + create/edit
  - Services: project_service
  - Models: project_model

### 4.2 Collaboration and communication

- Chat
  - chat listing/settings + messages, attachments, search, options, top bar
  - Services: chat_service, windows_notification_service, notification_service, post_notification_service
  - Models: chat_model, notification_model, file_model

- Feed and comments
  - feed listing + create/edit + comment sheet
  - Services: feed_service
  - Models: feed_model

- Notifications
  - notifications listing with BLoC
  - Services: notification_service, post_notification_service, reminder_service
  - Models: notification_model, reminder_model

### 4.3 Organization and master data

- Creation module (large admin setup area)
  - admins, employees, roles, departments, sub-departments, designations
  - lead/deal metadata masters: lead status/source/category/priority, deal status
  - Services: admin_service, employee_service, role_service, department_service, sub_department_service, designation_service
  - Models: admin_model, employee_model, role_model, department_model, sub_department_model, designation_model

### 4.4 Payroll and HR

- Worktime
- Attendance ledger
- Permissions/work approvals
- Salary ledger

Services:
- worktime_service
- attendance_service
- workpermission_service
- permission_service
- salary_service

Models:
- worktime_model
- attendance_model
- workpermission_model
- permission_model
- salary_ledger_model

### 4.5 Ops, observability, and maintenance

- Backup and restore
  - Services: backup_service, backup_import_service
  - Models: backup_model

- Download center/history
  - Service: download_service
  - Model: download_model

- Settings and versioning
  - Services: settings_service, version_service
  - Models: settings_model, version_model

- Logs and activity
  - login logs, activity logs, recent activity
  - Services: auth_service (login/activity save), recent_activity_service
  - Models: login_logs_model, activity_log_model, recent_activity_model

- Trash/soft-delete
  - Service: trash_service
  - Model: trash_model

- Developer diagnostics
  - developer area, app errors, Hive/SP data viewers

---

## 5) Database and Storage Analysis

## 5.1 Cloud data layer (Firestore)

### Firebase project identity

From firebase_options.dart:
- Project ID: leadcapture-79a43
- Platform app registrations: web/android/ios/macos/windows

### Firestore root collections

From firebase_config.dart and enum.dart:
- Top-level collections accessed directly:
  - users
  - admins
  - version
  - regions
  - system
  - errors

### Tenant-scoped data structure

Primary business data is generally under:
- users/{cid}/{collection}

Where collection can include:
- roles, designations, departments, subDepartments
- employees, admins
- chats, messages, notifications
- leadCategory, leadSource, leadStatus, leadPriority, dealStatus
- leads, clients, deals, tasks
- projects, events
- worktime, attendance, permission, worktimeFromHome, salaryLedger
- feed, loginLogs, activityLogs, recentActivity, settings, backups, trash, usersStatus

Common observed subcollections:
- leads/{leadId}/comments
- deals/{dealId}/comments
- chats/{chatId}/messages

### Data access style

- Service classes perform typed reads/writes using FirebaseFirestore
- CommonService provides generic add/update/set/delete/get helpers
- Activity logging is integrated into common write flows in multiple modules
- ErrorService writes stack traces and device metadata to errors collection

## 5.2 Local persistence layer

### Hive cache

From cache_service.dart:
- Hive is initialized on startup
- Reference/master boxes:
  - employees
  - admins
  - departments
  - designations
  - roles
  - subDepartments
  - leadCategory
  - leadStatus
  - leadPriority
  - dealStatus
- Meta box stores lastSync timestamp
- Sync strategy:
  - full periodic sync every 6 hours
  - on-demand single-document fetch when cache miss occurs

### SharedPreferences session and app flags

From spdb.dart and db.dart:
- Session keys include:
  - cid
  - employee/admin serialized payload
  - employee_login/admin_login
  - company_logo
- UI/app behavior flags include:
  - panelSettings
  - payrollEnabled
  - theme, locale
  - login and additional legacy flags in db.dart

## 5.3 File storage layer (Firebase Storage)

From enum.dart and storage_service.dart:
- Storage folder enum:
  - companyLogo
  - userPhotos
  - chats
  - leadAttachments
  - clientPhotos
  - clientCompanyLogos
  - dealAttachments
  - adminProfile
  - taskAttachments
  - feedAttachments

Upload paths follow:
- {cid}/{folder}/{uuid}.{ext}

## 5.4 Security and encryption behavior

From deterministic_crypto.dart and extensions.dart:
- Passwords are decrypted at login path using string extension decrypt
- Encryption utility derives key material from a fixed password seed text: leadcapture-crm
- Extension methods expose encrypt and decrypt wrappers globally on String

Operational note:
- A static application-level seed is used for cryptography initialization in client code. For production hardening, key material should be externalized and rotated via secure key management.

---

## 6) Screen Analysis

## 6.1 Coverage totals

Total screen-related Dart files discovered under lib/views/screens:
- 231 files

Module-wise counts:
- activitylogs: 4
- attendance: 3
- auth: 6
- backup: 4
- calendar: 7
- chat: 17
- clients: 9
- creations: 83
- dashboard: 5
- deals: 11
- developer: 5
- download: 4
- feed: 8
- leads: 12
- loginlogs: 4
- main: 5
- notifications: 4
- permission: 7
- projects: 7
- salary_ledger: 1
- settings: 5
- tasks: 10
- worktime: 9

## 6.2 Main user-facing screen surfaces by module

- Auth: login, forgot/reset password, initial password change, company registration
- Main shell: route screen, desktop main, mobile main, dashboard route entry
- CRM: leads, deals, clients
- Collaboration: chats, feed, notifications
- Scheduling: calendar, event create/edit
- Work operations: tasks, projects, downloads
- HR/Payroll: worktime, permissions, attendance ledger, salary ledger
- Admin setup: all creations submodules
- System/admin: settings, login logs, activity logs, backup, developer

## 6.3 Full screen inventory artifacts

Complete generated inventory files:
- docs/screen_inventory.txt
- docs/firebase_service_inventory.txt
- docs/database_service_inventory.txt
- docs/model_inventory.txt

These files enumerate every discovered Dart file in their respective domains and can be used as audit appendices.

---

## 7) Data Model Inventory

Model layer includes 42 domain models covering:
- Identity and user data
- CRM entities (lead/client/deal/task/project)
- Workflow metadata (status/category/priority/source)
- Communication (chat/notification/feed)
- Payroll and attendance
- Backup/version/settings/logging/error support

Refer to docs/model_inventory.txt for exact file-by-file coverage.

---

## 8) Integrations and Platform Notes

From pubspec.yaml and main flow:
- Firebase stack: core, firestore, storage, messaging
- Offline and local layers: Hive, SharedPreferences, localstore
- Desktop: local_notifier, window_manager, flutter_window_close
- UI stack includes flutter_bloc, provider, charting, calendar, media/file support
- Face API package exists (flutter_face_api) and appears connected to worktime/face scan screens

---

## 9) Observed Risks and Gaps

1. Security key management
- Crypto seed initialization is hard-coded in client layer.

2. Firestore access governance visibility
- This workspace view does not include Firestore security rules, so enforcement cannot be fully verified here.

3. Data-flow consistency
- Hybrid state patterns (Provider + BLoC + direct service calls) can increase maintenance complexity unless conventions are documented.

4. README quality
- README still contains default Flutter starter text and does not document architecture, setup, or data model.

5. Service breadth
- The creation module and Firestore service layer are broad, increasing coupling risk without API boundaries.

---

## 10) Recommended Next Steps

1. Add architecture documentation
- Add an official architecture doc with tenant model, collection map, and navigation map.

2. Externalize cryptographic key strategy
- Move encryption key derivation to secure key management and define rotation policy.

3. Publish Firestore rules and indexes
- Include firestore.rules and firestore.indexes.json in repository for auditability.

4. Define state-management conventions
- Standardize when to use Provider vs BLoC and document boundaries.

5. Improve test strategy
- Add module-level unit tests for service layer and integration tests for critical flows.

---

Report generated: April 14, 2026
Project path analyzed: c:/Users/ramsa/Flutter_projects/leadcapture
