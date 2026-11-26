import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// expenses.php: list, get, create, update, cancel (= delete), bulk_cancel,
/// export.
class ExpensesApiService {
  ExpensesApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.expenses, action: action, body: body ?? {});
}

/// expense_report.php: one call returns the filtered rows, summary, category
/// breakdown and the filter lookups.
class ExpenseReportApiService {
  ExpenseReportApiService._();
  static Future<ApiResponse> call([Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.expenseReport, action: 'report', body: body ?? {});
}