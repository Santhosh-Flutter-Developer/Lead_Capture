enum Collections {
  users,
  roles,
  designations,
  departments,
  subDepartments,
  employees,
  chats,
  messages,
  notifications,
  leadCategory,
  leadSource,
  leadStatus,
  leadPriority,
  dealStatus,
  leads,
  clients,
  deals,
  tasks,
  taskComments,
  taskHistory,
  comments,
  admins,
  projects,
  version,
  trash,
  workLogs,
  usersStatus,
  feed,
  loginLogs,
  activityLogs,
  settings,
  backups,
  recentActivity,
  errors,
  events,
  worktime,
  attendance,
  permission,
  worktimeFromHome,
  salaryLedger,
  companies,
  holidays,
  salaryTypes,
  employeeStatuses,
  leaveRequests,
  permissionRequests,
  customerTickets,
  ticketComments,
  ticketHistory,
  eventStartNotifications,
  projectUpdations,
  masterCompanies,
  payments,
  paymentMode,
}

enum StorageFolder {
  companyLogo,
  userPhotos,
  chats,
  leadAttachments,
  clientPhotos,
  clientCompanyLogos,
  dealAttachments,
  adminProfile,
  taskAttachments,
  feedAttachments,
  ticketAttachments,
  updationAttachments,
  paymentAttachments,
}

enum TicketCategory {
  bugReport,
  technicalSupport,
  changeRequest,
  enhancementRequest,
  applicationIssue,
  serverIssue,
  databaseIssue,
  networkIssue,
}

extension TicketCategoryX on TicketCategory {
  String get label {
    switch (this) {
      case TicketCategory.bugReport:
        return 'Bug Report';
      case TicketCategory.technicalSupport:
        return 'Technical Support';
      case TicketCategory.changeRequest:
        return 'Change Request';
      case TicketCategory.enhancementRequest:
        return 'Enhancement Request';
      case TicketCategory.applicationIssue:
        return 'Application Issue';
      case TicketCategory.serverIssue:
        return 'Server Issue';
      case TicketCategory.databaseIssue:
        return 'Database Issue';
      case TicketCategory.networkIssue:
        return 'Network Issue';
    }
  }
}

enum TicketStatus {
  open,
  assigned,
  inProgress,
  onHold,
  pendingCustomerResponse,
  resolved,
  closed,
}

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.assigned:
        return 'Assigned';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.onHold:
        return 'On Hold';
      case TicketStatus.pendingCustomerResponse:
        return 'Pending Customer Response';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }
}

/// How each ticket status affects the time tracker:
///  * In Progress                          -> timer runs
///  * On Hold / Pending Customer Response  -> timer paused (waiting time isn't work)
///  * Resolved / Closed                    -> timer stopped
///  * Open / Assigned                      -> not started yet
extension TicketStatusTimerX on TicketStatus {
  bool get isTimerRunning => this == TicketStatus.inProgress;
  bool get isTimerPaused =>
      this == TicketStatus.onHold || this == TicketStatus.pendingCustomerResponse;
  bool get isTimerStopped =>
      this == TicketStatus.resolved || this == TicketStatus.closed;
}

/// Workflow status of a task.
///
/// [pending] is the implicit initial state (task not started yet) and is never
/// stored. The other values are what the status dropdown offers.
enum TaskStatus { pending, started, inProgress, onHold, completed }

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.started:
        return 'Started';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.onHold:
        return 'On Hold';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  /// Statuses the user can pick from the dropdown.
  static const List<TaskStatus> selectable = [
    TaskStatus.started,
    TaskStatus.inProgress,
    TaskStatus.onHold,
    TaskStatus.completed,
  ];
}

enum TicketPriority { low, medium, high, urgent }

extension TicketPriorityX on TicketPriority {
  String get label {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.urgent:
        return 'Urgent';
    }
  }
}

enum TicketModeOfContact { whatsApp, mail, phone, visit }

extension TicketModeOfContactX on TicketModeOfContact {
  String get label {
    switch (this) {
      case TicketModeOfContact.whatsApp:
        return 'WhatsApp';
      case TicketModeOfContact.mail:
        return 'Mail';
      case TicketModeOfContact.phone:
        return 'Phone';
      case TicketModeOfContact.visit:
        return 'Visit';
    }
  }
}

enum LeadSource { email, google, facebook, phone, directVisit, other }

enum PlatformType { mobile, desktop }

enum UserType { admin, employee }

enum EventRepeatType { none, daily, weekly, monthly, yearly }

enum Calendar { day, week, month }

enum ChatAction { pin, favorite, delete }

enum ClientSection { contacts, company }

enum LeadCompletionStatus { won, lost, disqualified }

extension LeadCompletionStatusX on LeadCompletionStatus {
  String get label {
    switch (this) {
      case LeadCompletionStatus.won:
        return 'Won';
      case LeadCompletionStatus.lost:
        return 'Lost';
      case LeadCompletionStatus.disqualified:
        return 'Disqualified';
    }
  }
}

enum UserData { uid, name, img, mobileNumber, collectionId, type }

enum FilterRequirements { staff }

enum LeadActivityType { call, meeting, followUp, task }

enum DealActivityType { call, meeting, followUp, task }

enum HalfDaySession { morning, evening }

enum PermissionsStatus { pending, approved, rejected }

enum PermissionType {
  permission,
  leaveFullDay,
  leaveHalfDay,
  workFromHome,
  lateEntry,
  earlyExit,
}

enum AttendanceStatus {
  present,
  absent,
  leave,
  holiday,
  wfh,
  halfDay,
  late,
  earlyExit,
  lessHours,
  pending,
  rejected,
}

enum NotificationType {
  alert,
  info,
  openFile,
  task,
  permissionRequest,
  lead,
  eventReminder,
  eventStarted,
  deal,
  chat,
  success,
  warning,
  error,
  feed,
  ticket,
  project,
}

/// Lifecycle of the server-scheduled "event started" push notification for
/// a calendar event. Written by the Cloud Function, read-only from the app.
enum EventNotificationStatus { pending, scheduled, sent, cancelled, failed }