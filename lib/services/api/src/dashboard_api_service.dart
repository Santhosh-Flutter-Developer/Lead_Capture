import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// dashboard.php
class DashboardApiService {
  DashboardApiService._();
  /// filter: Today | Yesterday | This Week | This Month | Custom (+ start/end 'YYYY-MM-DD')
  static Future<ApiResponse> overview({String filter = 'Today', String? startDate, String? endDate}) =>
      ApiClient.instance.post(ApiEndpoints.dashboard, action: 'overview', body: {
        'filter': filter,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      });
}
