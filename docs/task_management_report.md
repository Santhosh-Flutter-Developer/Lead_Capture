# Task Management Module Report

## 1) Scope

This report analyzes the task management module in the LeadCapture Flutter app, focusing on:
- Features included
- Access permissions
- Database and model structure
- Screen flow and UI surfaces
- Missing or incomplete features

Primary code references:
- [lib/services/firebase/src/task_service.dart](lib/services/firebase/src/task_service.dart)
- [lib/views/screens/tasks/tasks.dart](lib/views/screens/tasks/tasks.dart)
- [lib/views/screens/tasks/listing/tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart)
- [lib/views/screens/tasks/form/task_create.dart](lib/views/screens/tasks/form/task_create.dart)
- [lib/views/screens/tasks/form/task_edit.dart](lib/views/screens/tasks/form/task_edit.dart)
- [lib/views/screens/tasks/form/task_view.dart](lib/views/screens/tasks/form/task_view.dart)
- [lib/views/screens/tasks/listing/task_calendar_listing.dart](lib/views/screens/tasks/listing/task_calendar_listing.dart)
- [lib/views/screens/tasks/listing/task_status_pie_chart.dart](lib/views/screens/tasks/listing/task_status_pie_chart.dart)
- [lib/models/src/task_model.dart](lib/models/src/task_model.dart)
- [lib/services/firebase/src/permission_service.dart](lib/services/firebase/src/permission_service.dart)

---

## 2) Executive Summary

The task module is a full-featured CRM task workflow with:
- Task creation, editing, deletion
- Task listing with filtering, sorting, pagination, selection, and bulk delete
- Task detail view with comments, activity history, time tracking, attachments, and start/complete actions
- Calendar and status summary views
- Firestore-backed storage with subcollections for history, comments, and time logs

Access control is mixed:
- Admin users receive full access automatically through PermissionService
- Non-admin users are governed by page-level permissions for Tasks
- The list screen checks canView, canCreate, canEdit, and canDelete
- The detail screen itself exposes task actions without an additional task-specific permission gate

The module is functional, but several important governance and collaboration features are still missing or only partially implemented.

---

## 3) What the Task Module Includes

### 3.1 Task listing and browsing

The task list screen supports:
- Viewing tasks in a data table
- Searching by task name and tags
- Sorting by task name, deadline, and task number
- Pagination
- Multi-select rows for bulk delete
- Switching between list view and calendar view
- Opening a task detail sheet from each row
- Inline edit and delete actions per row

Evidence:
- View gate and action permissions are enforced in the listing screen at [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L110), [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L327), [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L365), [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L634), and [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L659)

### 3.2 Task creation

The create screen supports:
- Task title
- Description
- Priority toggle
- Deadline picker
- Reminder picker
- Assignees
- Created-by selection
- Observers
- Participants
- Project linkage
- Lead linkage
- Subtask linkage
- Tags
- Attachments
- Deadline-required flag
- Status summary flag

The create flow is driven by the task model and service layer, with task numbering assigned on save.

### 3.3 Task editing

The edit screen supports the same core field set as create, plus preloading existing data:
- Task metadata
- Role-related user lists
- Project/lead/subtask context
- Attachments and timing fields
- Existing assignees, creators, participants, observers

### 3.4 Task details

The detail screen includes:
- Urgency and status badges
- Deadline and reminder summary
- Description section
- Attachment download grid
- Comments tab
- Activity history tab
- Time tracking tab
- Start task action
- Complete task action
- Comment posting

The detail view is more than a read-only form; it acts as the operational hub for task progress.

### 3.5 Task analytics and alternate views

The module also includes supporting visualizations and alternate views:
- Calendar view for tasks
- Task status pie chart component
- Task listing supports switching between list and calendar views

The task module exports both [task_calendar_listing.dart](lib/views/screens/tasks/listing/task_calendar_listing.dart) and [task_status_pie_chart.dart](lib/views/screens/tasks/listing/task_status_pie_chart.dart), which indicates the module was intended to support both operational and analytical workflows.

---

## 4) Access Permissions

### 4.1 How permissions work

Task permissions are page-level permissions stored through PermissionService.

- Admin users automatically get full access to every page
- Non-admin users depend on stored permission flags for the Tasks page

Reference:
- [PermissionService.getPermissions](lib/services/firebase/src/permission_service.dart#L14)

### 4.2 Permissions enforced in the task list

The listing screen checks:
- canView before rendering the module content
- canCreate before enabling Add Task
- canDelete before enabling bulk delete
- canEdit before enabling row edit action
- canDelete before enabling row delete action

Reference points:
- [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L110)
- [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L327)
- [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L365)
- [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L634)
- [tasks_listing.dart](lib/views/screens/tasks/listing/tasks_listing.dart#L659)

### 4.3 Permissions in the task detail flow

The task detail screen exposes:
- start task
- complete task
- comment posting
- attachment downloads
- history viewing

There is no separate permission check inside the detail screen for these actions. In practice, access is inherited from the fact that the task appears in the list query and can be opened from there.

### 4.4 Who can see tasks

Task streaming is restricted to tasks where the current user appears in one of these arrays:
- assignees
- createdBy
- observers
- participants

Reference:
- [tasks_bloc.dart](lib/views/screens/tasks/listing/bloc/tasks_bloc.dart#L17)

This means users do not see every task in the company by default; they see only tasks tied to them through one of those relationships.

### 4.5 Admin behavior

Admins are treated as fully privileged by the permission service. That means:
- All Tasks page permissions resolve to true
- Admins can create, edit, delete, and view without being blocked by page-level permission checks

---

## 5) Data and Database Design

### 5.1 Main collection

Task records live under the tenant-scoped Firestore path:
- users/{companyId}/tasks

### 5.2 Subcollections and related paths

The task service uses these nested collections and supporting structures:
- taskHistory for action history
- taskComments for discussion comments
- taskTimeLogs for start/complete timing records
- trash for soft-delete handling through TrashService
- activityLogs for audit logging

Reference:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L43)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L286)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L303)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L358)

### 5.3 Task model structure

The task model stores:
- task number
- task name and description
- deadline and reminder
- high priority flag
- deadline required flag
- status summary required flag
- assignees, createdBy, observers, participants
- tags
- project, lead, subTaskOf
- started/completed state and timestamps
- attachments
- comments
- history
- creator metadata
- createdAt and updatedAt timestamps

Reference:
- [task_model.dart](lib/models/src/task_model.dart)

### 5.4 Sequence on create/update/delete

- Create writes the task document, writes an initial history record, and sends notifications
- Update writes the task document, appends a history record, and sends notifications
- Delete moves the document to trash, deletes the live record, and logs an activity entry

References:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L9)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L103)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L187)

---

## 6) Feature Detail by Workflow

### 6.1 Create task

Implemented behaviors:
- Auto-assign creator into createdBy if missing
- Auto-generate incremental task number
- Persist full task payload
- Create initial task history entry
- Notify all involved users
- Schedule a reminder when deadlineRequired is enabled

References:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L9)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L21)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L37)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L49)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L83)

### 6.2 Update task

Implemented behaviors:
- Save edited task fields
- Append task history entry
- Notify all involved users
- Reschedule reminder when deadlineRequired is active

References:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L103)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L118)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L131)

### 6.3 Start task

Implemented behaviors:
- Prevents starting another active task for the same user
- Sets hasStarted and startedTime
- Adds a taskTimeLogs entry
- Adds a task history entry

Reference:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L256)

### 6.4 Complete task

Implemented behaviors:
- Sets completed and completedTime
- Closes the active taskTimeLogs entry
- Adds a task history entry

Reference:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L335)

### 6.5 Comments

Implemented behaviors:
- Real-time comment streaming
- Add comment support
- Comments display creator and timestamp in the detail view

Reference:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L405)
- [task_service.dart](lib/services/firebase/src/task_service.dart#L469)
- [task_view.dart](lib/views/screens/tasks/form/task_view.dart#L591)

### 6.6 History

Implemented behaviors:
- Real-time history streaming
- History entries record user and disposition
- History is shown in the detail view

Reference:
- [task_service.dart](lib/services/firebase/src/task_service.dart#L387)
- [task_view.dart](lib/views/screens/tasks/form/task_view.dart#L725)

### 6.7 Attachments

Implemented behaviors:
- Attachments are stored on the task model
- Task detail shows attachment cards
- Attachment tap downloads the file

Reference:
- [task_view.dart](lib/views/screens/tasks/form/task_view.dart#L423)

### 6.8 Calendar and analytics

Implemented behaviors:
- Task calendar listing exists
- Task status pie chart component exists
- Task module exports both components

References:
- [tasks.dart](lib/views/screens/tasks/tasks.dart#L1)
- [task_calendar_listing.dart](lib/views/screens/tasks/listing/task_calendar_listing.dart)
- [task_status_pie_chart.dart](lib/views/screens/tasks/listing/task_status_pie_chart.dart)

---

## 7) Missing or Incomplete Features

### 7.1 No comment edit or delete flow

The task service exposes:
- addComment
- streamComments
- streamTaskHistory

A separate edit/delete comment capability was not found in the task service or task detail UI. Comments appear to be append-only from the task module UI.

### 7.2 No explicit task-level ownership enforcement

The list screen uses page permissions and membership-based visibility, but there is no extra rule preventing a user with Tasks page permission from editing or deleting a task they did not create, as long as the page permission allows it.

This means the module depends on the broader page permission model rather than per-record ownership enforcement.

### 7.3 No fine-grained permission checks inside the detail view

The task detail screen exposes start, complete, and comment actions without a second permission gate. That is workable, but it means the permission model is coarse and centralized at listing access rather than action-level control.

### 7.4 Task analytics are present but not clearly primary

The module contains a pie-chart component and calendar view, but the main list screen defaults to list view. The analytics surfaces look supplementary rather than central.

### 7.5 No built-in comment moderation or threading

There is no indication of:
- edit history for comments
- reply threading
- delete/restore for comments
- reaction support
- comment pinning or assignment

### 7.6 No workflow approval state

The task workflow is operational, but it does not show:
- task approval/rejection states
- task dependency chain management
- escalations or SLA timers
- recurring task generation

### 7.7 No explicit file lifecycle management inside task detail

Attachments can be downloaded from the task view, but task-side upload, replacement, and per-file deletion controls were not evident in the detail view code that was reviewed.

---

## 8) User Experience Observations

- The module is operationally rich and fairly complete for a CRM task workflow.
- The list/detail split is clean.
- The module supports both operational tracking and collaboration.
- The strongest missing area is governance around edits and comment lifecycle.

---

## 9) Overall Assessment

The task management module is one of the more complete areas of the application.
It covers the core lifecycle well:
- create
- edit
- assign
- start
- complete
- discuss
- review history
- track time
- view by calendar

The main weakness is access control depth. Permissions are page-level and membership-based, but not tightly enforced at the individual task action level. Comment management is also incomplete compared with the rest of the workflow.

---

## 10) Suggested Next Improvements

1. Add task ownership rules
- Enforce creator/assignee/manager rules for edit and delete actions.

2. Add comment lifecycle controls
- Add comment edit/delete, soft delete, and audit trail support.

3. Add action-level permissions
- Gate start/complete/comment actions by role and record membership.

4. Add richer workflow states
- Add approval, blocked, overdue, dependency, and recurrence support.

5. Make analytics more visible
- Surface the task summary chart more prominently in the main task experience.

---

## Appendix: Coverage Inventory

Task-related files discovered in this workspace are listed in:
- [docs/screen_inventory.txt](docs/screen_inventory.txt)
- [docs/firebase_service_inventory.txt](docs/firebase_service_inventory.txt)
- [docs/model_inventory.txt](docs/model_inventory.txt)

Report generated: April 14, 2026
