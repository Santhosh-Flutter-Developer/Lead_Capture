import 'dart:convert';
import 'package:flutter/foundation.dart';
import '/models/models.dart';

class ProjectModel {
  final String? uid;
  final String projectName;
  final String projectDescription;
  final String projectOwner;
  final String teamLead;
  final List<String> members;
  final String? client;
  final String? clientId; // Master Client
  final String? dealId; // Deal this project came from
  final String? projectCode;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? deadline;
  final String? tags;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  ProjectModel({
    this.uid,
    required this.projectName,
    required this.projectDescription,
    required this.projectOwner,
    required this.teamLead,
    required this.members,
    this.client,
    this.clientId,
    this.dealId,
    this.projectCode,
    this.category,
    this.startDate,
    this.endDate,
    this.deadline,
    this.tags,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ProjectModel copyWith({
    String? uid,
    String? projectName,
    String? projectDescription,
    String? projectOwner,
    String? teamLead,
    List<String>? members,
    String? client,
    String? clientId,
    String? dealId,
    String? projectCode,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? deadline,
    String? tags,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      uid: uid ?? this.uid,
      projectName: projectName ?? this.projectName,
      projectDescription: projectDescription ?? this.projectDescription,
      projectOwner: projectOwner ?? this.projectOwner,
      teamLead: teamLead ?? this.teamLead,
      members: members ?? this.members,
      client: client ?? this.client,
      clientId: clientId ?? this.clientId,
      dealId: dealId ?? this.dealId,
      projectCode: projectCode ?? this.projectCode,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      deadline: deadline ?? this.deadline,
      tags: tags ?? this.tags,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'projectName': projectName,
      'projectDescription': projectDescription,
      'projectOwner': projectOwner,
      'teamLead': teamLead,
      'members': members,
      'client': client,
      'clientId': clientId,
      'dealId': dealId,
      'projectCode': projectCode,
      'category': category,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'deadline': deadline?.millisecondsSinceEpoch,
      'tags': tags,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'projectName': projectName,
      'projectDescription': projectDescription,
      'projectOwner': projectOwner,
      'teamLead': teamLead,
      'members': members,
      'client': client,
      'clientId': clientId,
      'dealId': dealId,
      'projectCode': projectCode,
      'category': category,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'deadline': deadline?.millisecondsSinceEpoch,
      'tags': tags,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ProjectModel.fromMap(String uid, Map<String, dynamic> map) {
    return ProjectModel(
      uid: uid,
      projectName: map['projectName'] != null && map['projectName'] is String
          ? map['projectName'] as String
          : '',
      projectDescription:
          map['projectDescription'] != null &&
              map['projectDescription'] is String
          ? map['projectDescription'] as String
          : '',
      projectOwner: map['projectOwner'] != null && map['projectOwner'] is String
          ? map['projectOwner'] as String
          : '',
      teamLead: map['teamLead'] != null && map['teamLead'] is String
          ? map['teamLead'] as String
          : '',
      members: map['members'] != null ? List<String>.from(map['members']) : [],
      client: map['client'] != null && map['client'] is String
          ? map['client'] as String
          : null,
      clientId: map['clientId'] is String ? map['clientId'] as String : null,
      dealId: map['dealId'] is String ? map['dealId'] as String : null,
      projectCode: map['projectCode'] != null && map['projectCode'] is String
          ? map['projectCode'] as String
          : null,
      category: map['category'] != null && map['category'] is String
          ? map['category'] as String
          : null,
      startDate: map['startDate'] != null && map['startDate'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
          : null,
      endDate: map['endDate'] != null && map['endDate'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
          : null,
      deadline: map['deadline'] != null && map['deadline'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
          : null,
      tags: map['tags'] != null && map['tags'] is String
          ? map['tags'] as String
          : null,
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: map['createdAt'] != null && map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null && map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ProjectModel.fromJson(String uid, String source) =>
      ProjectModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ProjectModel(uid: $uid, projectName: $projectName, projectDescription: $projectDescription, projectOwner: $projectOwner, members: $members, client: $client, projectCode: $projectCode, category: $category, startDate: $startDate, endDate: $endDate, deadline: $deadline, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant ProjectModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.projectName == projectName &&
        other.projectDescription == projectDescription &&
        other.projectOwner == projectOwner &&
        other.teamLead == teamLead &&
        listEquals(other.members, members) &&
        other.client == client &&
        other.projectCode == projectCode &&
        other.category == category &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.deadline == deadline &&
        other.tags == tags &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        projectName.hashCode ^
        projectDescription.hashCode ^
        projectOwner.hashCode ^
        teamLead.hashCode ^
        members.hashCode ^
        client.hashCode ^
        projectCode.hashCode ^
        category.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        deadline.hashCode ^
        tags.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}