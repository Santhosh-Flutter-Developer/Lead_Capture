import '/models/models.dart';
import '/services/api/api.dart';

/// "Recent activity" on the dashboard. The server records activity itself
/// (activity_logs) and returns the latest entries in dashboard.php
/// `overview` → `recentActivities`, so nothing is written from the client.
class RecentActivityService {
  Future<List<ActivityItem>> getRecentActivities() async {
    final res = (await DashboardApiService.overview(filter: 'All')).ensureSuccess();
    final list = Js.mapList(res.dataMap['recentActivities']);
    var i = 0;
    return list.map((m) {
      i++;
      final page = Js.s(m['page']);
      final action = Js.s(m['action']);
      return ActivityItem(
        index: i,
        page: action.isEmpty ? page : '$page · $action',
        visitedAt: DateTime.tryParse(Js.s(m['date_time'])) ?? DateTime.now(),
      );
    }).toList();
  }

  /// No-op: the server logs activity.
  Future<void> addActivity({required String page, int maxItems = 10}) async {}
}
