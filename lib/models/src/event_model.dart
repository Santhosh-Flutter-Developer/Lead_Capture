// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '/constants/constants.dart';
import '/models/models.dart';

/// Kind of calendar event shown in the "Event Type" dropdown / detail view.
enum EventType { meeting, call, reminder, appointment, deadline, other }

extension EventTypeX on EventType {
  String get label {
    switch (this) {
      case EventType.meeting:
        return 'Meeting';
      case EventType.call:
        return 'Call';
      case EventType.reminder:
        return 'Reminder';
      case EventType.appointment:
        return 'Appointment';
      case EventType.deadline:
        return 'Deadline';
      case EventType.other:
        return 'Other';
    }
  }

  static EventType fromName(String? name) => EventType.values.firstWhere(
    (e) => e.name == (name ?? '').trim().toLowerCase(),
    orElse: () => EventType.meeting,
  );
}

extension EventRepeatTypeX on EventRepeatType {
  /// Label used by the "Repeat Schedule" dropdown.
  String get scheduleLabel {
    switch (this) {
      case EventRepeatType.none:
        return 'Does not repeat';
      case EventRepeatType.daily:
        return 'Daily';
      case EventRepeatType.weekly:
        return 'Weekly';
      case EventRepeatType.monthly:
        return 'Monthly';
      case EventRepeatType.yearly:
        return 'Yearly';
    }
  }
}

class EventModel {
  /// Default accent colour (brand blue).
  static const int defaultAccent = 0xFF4364F7;

  final String? uid;
  final String eventName;
  final DateTime eventDateTime;
  final DateTime eventEndDateTime;
  final String eventDescription;
  final EventRepeatType eventRepeatType;
  final List<String> eventAttendes;
  final UserDataModel createdBy;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Meeting / call / reminder ... (shown on cards and in the detail view).
  final EventType eventType;

  /// ARGB colour value used to paint this event on the calendar.
  final int accentColor;

  /// All-day events have no specific start / end time.
  final bool allDay;

  /// Status of the server-scheduled "Event Started" push notification.
  /// Set to [EventNotificationStatus.pending] on the client when the event
  /// is created; everything after that is written by the
  /// `onEventWritten` / `sendEventStartNotifications` Cloud Functions.
  final EventNotificationStatus notificationStatus;
  EventModel({
    this.uid,
    required this.eventName,
    required this.eventDateTime,
    required this.eventEndDateTime,
    required this.eventDescription,
    required this.eventRepeatType,
    required this.eventAttendes,
    required this.createdBy,
    this.completed = false,
    this.eventType = EventType.meeting,
    this.accentColor = defaultAccent,
    this.allDay = false,
    this.notificationStatus = EventNotificationStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  EventModel copyWith({
    String? uid,
    String? eventName,
    DateTime? eventDateTime,
    DateTime? eventEndDateTime,
    String? eventDescription,
    EventRepeatType? eventRepeatType,
    List<String>? eventAttendes,
    UserDataModel? createdBy,
    bool? completed,
    EventType? eventType,
    int? accentColor,
    bool? allDay,
    EventNotificationStatus? notificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      uid: uid ?? this.uid,
      eventName: eventName ?? this.eventName,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      eventEndDateTime: eventEndDateTime ?? this.eventEndDateTime,
      eventDescription: eventDescription ?? this.eventDescription,
      eventRepeatType: eventRepeatType ?? this.eventRepeatType,
      eventAttendes: eventAttendes ?? this.eventAttendes,
      createdBy: createdBy ?? this.createdBy,
      completed: completed ?? this.completed,
      eventType: eventType ?? this.eventType,
      accentColor: accentColor ?? this.accentColor,
      allDay: allDay ?? this.allDay,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'eventName': eventName,
      'eventDateTime': eventDateTime.millisecondsSinceEpoch,
      'eventEndDateTime': eventEndDateTime.millisecondsSinceEpoch,
      'eventDescription': eventDescription,
      'eventRepeatType': eventRepeatType.name,
      'eventAttendes': eventAttendes,
      'createdBy': createdBy.toMap(),
      'completed': completed,
      'eventType': eventType.name,
      'accentColor': accentColor,
      'allDay': allDay,
      'notificationStatus': notificationStatus.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'eventName': eventName,
      'eventDateTime': eventDateTime.millisecondsSinceEpoch,
      'eventEndDateTime': eventEndDateTime.millisecondsSinceEpoch,
      'eventDescription': eventDescription,
      'eventRepeatType': eventRepeatType.name,
      'eventAttendes': eventAttendes,
      'createdBy': createdBy.toMap(),
      'completed': completed,
      'eventType': eventType.name,
      'accentColor': accentColor,
      'allDay': allDay,
      // Editing the event always puts the server-side notification back to
      // "pending" — the onEventWritten trigger re-evaluates and reschedules
      // it. We never let the client set it to sent/cancelled directly.
      'notificationStatus': EventNotificationStatus.pending.name,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory EventModel.fromMap(String uid, Map<String, dynamic> map) {
    return EventModel(
      uid: uid,
      eventName: map['eventName'] as String,
      eventDateTime: DateTime.fromMillisecondsSinceEpoch(
        map['eventDateTime'] as int,
      ),
      eventEndDateTime: DateTime.fromMillisecondsSinceEpoch(
        map['eventEndDateTime'] as int,
      ),
      eventDescription: map['eventDescription'] as String,
      eventRepeatType: EventRepeatType.values.byName(
        map['eventRepeatType'] as String,
      ),
      eventAttendes: List<String>.from((map['eventAttendes'] as List<dynamic>)),
      createdBy: UserDataModel.fromMap(
        map['createdBy'] as Map<String, dynamic>,
      ),
      completed: map['completed'] != null && map['completed'] is bool
          ? map['completed'] as bool
          : false,
      eventType: EventTypeX.fromName(map['eventType'] as String?),
      accentColor: map['accentColor'] is int
          ? map['accentColor'] as int
          : defaultAccent,
      allDay: map['allDay'] is bool ? map['allDay'] as bool : false,
      notificationStatus: map['notificationStatus'] != null
          ? EventNotificationStatus.values.byName(
              map['notificationStatus'] as String,
            )
          : EventNotificationStatus.pending,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventModel.fromJson(String uid, String source) =>
      EventModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'EventModel(uid: $uid, eventName: $eventName, eventDateTime: $eventDateTime, eventEndDateTime: $eventEndDateTime, eventDescription: $eventDescription, eventRepeatType: $eventRepeatType, eventAttendes: $eventAttendes, createdBy: $createdBy, notificationStatus: $notificationStatus, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant EventModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.eventName == eventName &&
        other.eventDateTime == eventDateTime &&
        other.eventEndDateTime == eventEndDateTime &&
        other.eventDescription == eventDescription &&
        other.eventRepeatType == eventRepeatType &&
        other.eventType == eventType &&
        other.accentColor == accentColor &&
        other.allDay == allDay &&
        listEquals(other.eventAttendes, eventAttendes) &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        eventName.hashCode ^
        eventDateTime.hashCode ^
        eventEndDateTime.hashCode ^
        eventDescription.hashCode ^
        eventRepeatType.hashCode ^
        eventType.hashCode ^
        accentColor.hashCode ^
        allDay.hashCode ^
        eventAttendes.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}