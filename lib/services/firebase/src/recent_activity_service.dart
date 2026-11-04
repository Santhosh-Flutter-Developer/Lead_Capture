import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';
import '/constants/constants.dart';
import '/services/services.dart';

class RecentActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ActivityItem>> getRecentActivities() async {
    final cid = await Spdb.getCid();
    final userId = await Spdb.getUid();

    final doc = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.recentActivity.name)
        .doc(userId)
        .get();

    if (!doc.exists) return [];

    final List list = doc.data()!['activities'] ?? [];

    return list.map((e) {
      return ActivityItem(
        index: e['index'],
        page: e['page'],
        visitedAt: (e['visitedAt'] as Timestamp).toDate(),
      );
    }).toList();
  }

  Future<void> addActivity({required String page, int maxItems = 10}) async {
    final cid = await Spdb.getCid();
    final userId = await Spdb.getUid();

    if (cid == null || userId == null) return;

    final query = _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.recentActivity.name)
        .doc(userId);

    final snapshot = await query.get();

    List<Map<String, dynamic>> activities = [];

    if (snapshot.exists) {
      final doc = snapshot;

      final data = doc.data();
      if (data?['activities'] is List) {
        activities = List<Map<String, dynamic>>.from(data?['activities']);
      }
    }

    // 🔹 Remove same page if already exists
    activities.removeWhere((e) => e['page'] == page);

    // 🔹 Insert at top
    activities.insert(0, {'page': page, 'visitedAt': DateTime.now()});

    // 🔹 Limit items
    if (activities.length > maxItems) {
      activities = activities.take(maxItems).toList();
    }

    // 🔹 Recalculate index (CORRECT WAY)
    for (int i = 0; i < activities.length; i++) {
      activities[i]['index'] = i + 1;
    }

    if (snapshot.exists) {
      await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.recentActivity.name)
          .doc(userId)
          .update({'activities': activities});
    } else {
      await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.recentActivity.name)
          .doc(userId)
          .set({'userId': userId, 'activities': activities});
    }
  }
}
