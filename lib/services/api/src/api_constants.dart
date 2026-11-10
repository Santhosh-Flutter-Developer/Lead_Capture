/// Endpoint file names exactly as documented in API_DOCUMENTATION (1).md.
class ApiEndpoints {
  ApiEndpoints._();
  static const auth = 'auth.php';
  static const employees = 'employees.php';
  static const roles = 'roles.php';
  static const masters = 'masters.php';
  static const dashboard = 'dashboard.php';
  static const leads = 'leads.php';
  static const deals = 'deals.php';
  static const projects = 'projects.php';
  static const tasks = 'tasks.php';
  static const tickets = 'tickets.php';
  static const projectUpdations = 'project_updations.php';
  static const payments = 'payments.php';
  static const masterClients = 'master_clients.php';
  static const masterCompanies = 'master_companies.php';
  static const notifications = 'notifications.php';
  static const upload = 'upload.php';
  static const chats = 'chats.php';
  static const feed = 'feed.php';
  static const logs = 'logs.php';
  static const settings = 'settings.php';
  static const locations = 'locations.php';
  static const calendar = 'calendar.php';
}

/// `type` values accepted by masters.php.
class MasterTypes {
  MasterTypes._();
  static const leadSource = 'lead_source';
  static const leadStatus = 'lead_status';
  static const leadPriority = 'lead_priority';
  static const leadCategory = 'lead_category';
  static const dealStatus = 'deal_status';
  static const paymentMode = 'payment_mode';
  static const department = 'department';
  static const subDepartment = 'sub_department';
  static const designation = 'designation';
}

/// `module` values accepted by upload.php.
class UploadModules {
  UploadModules._();
  static const profile = 'profile';
  static const lead = 'lead';
  static const deal = 'deal';
  static const task = 'task';
  static const ticket = 'ticket';
  static const payment = 'payment';
  static const updation = 'updation';
}
