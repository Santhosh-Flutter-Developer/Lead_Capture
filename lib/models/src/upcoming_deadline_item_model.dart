class UpcomingDeadlineItemModel {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final String source;

  UpcomingDeadlineItemModel({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'scheduledAt': scheduledAt.millisecondsSinceEpoch,
      'source': source,
    };
  }

  factory UpcomingDeadlineItemModel.fromMap(Map<String, dynamic> map) {
    return UpcomingDeadlineItemModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      scheduledAt: map['scheduledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'] as int)
          : DateTime.now(),
      source: map['source']?.toString() ?? 'task',
    );
  }
}
