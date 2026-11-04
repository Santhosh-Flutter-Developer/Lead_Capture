// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RecentActivityModel {
  final String userId;
  final List<ActivityItem> activities;

  RecentActivityModel({required this.userId, required this.activities});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'activities': activities.map((x) => x.toMap()).toList(),
    };
  }

  RecentActivityModel copyWith({
    String? userId,
    List<ActivityItem>? activities,
  }) {
    return RecentActivityModel(
      userId: userId ?? this.userId,
      activities: activities ?? this.activities,
    );
  }

  factory RecentActivityModel.fromMap(Map<String, dynamic> map) {
    return RecentActivityModel(
      userId: map['userId'] as String,
      activities: List<ActivityItem>.from(
        (map['activities'] as List).map<ActivityItem>(
          (x) => ActivityItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory RecentActivityModel.fromJson(String source) =>
      RecentActivityModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'RecentActivityModel(userId: $userId, activities: $activities)';

  @override
  bool operator ==(covariant RecentActivityModel other) {
    if (identical(this, other)) return true;

    return other.userId == userId && listEquals(other.activities, activities);
  }

  @override
  int get hashCode => userId.hashCode ^ activities.hashCode;
}

class ActivityItem {
  final int index;
  final String page;
  final DateTime visitedAt;

  ActivityItem({
    required this.index,
    required this.page,
    required this.visitedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'index': index,
      'page': page,
      'visitedAt': visitedAt.millisecondsSinceEpoch,
    };
  }

  ActivityItem copyWith({int? index, String? page, DateTime? visitedAt}) {
    return ActivityItem(
      index: index ?? this.index,
      page: page ?? this.page,
      visitedAt: visitedAt ?? this.visitedAt,
    );
  }

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    return ActivityItem(
      index: map['index'] as int,
      page: map['page'] as String,
      visitedAt: map['visitedAt'] is Timestamp
          ? (map['visitedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ActivityItem.fromJson(String source) =>
      ActivityItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'ActivityItem(index: $index, page: $page, visitedAt: $visitedAt)';

  @override
  bool operator ==(covariant ActivityItem other) {
    if (identical(this, other)) return true;

    return other.index == index &&
        other.page == page &&
        other.visitedAt == visitedAt;
  }

  @override
  int get hashCode => index.hashCode ^ page.hashCode ^ visitedAt.hashCode;
}
