import 'dart:convert';
import '/models/models.dart';

enum UpdationStatus { pending, inProgress, completed }

extension UpdationStatusX on UpdationStatus {
  String get label {
    switch (this) {
      case UpdationStatus.pending:
        return 'Pending';
      case UpdationStatus.inProgress:
        return 'In Progress';
      case UpdationStatus.completed:
        return 'Completed';
    }
  }

  static UpdationStatus fromName(String? name) {
    return UpdationStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => UpdationStatus.pending,
    );
  }
}

/// A change / update request raised against an existing Project.
/// One project can have many updations.
class ProjectUpdationModel {
  final String? uid;
  final int? updationNumber;
  final String projectId;
  final String projectName;
  final String? clientId;
  final String? companyName;
  final String? contactName;
  final String? contactMobile;
  final String title;
  final String description;
  final DateTime requestedDate;
  final UpdationStatus status;
  final double? value;
  final DateTime? deadline;
  final String? assigneeId;
  final String? assigneeName;
  final List<FileModel> attachments;
  final String notes;
  /// Employee (uid) responsible for the follow-up. When set, only this
  /// employee and admins can see the record. `null` = visible as before.
  final String? followUp;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectUpdationModel({
    this.uid,
    this.updationNumber,
    required this.projectId,
    required this.projectName,
    this.clientId,
    this.companyName,
    this.contactName,
    this.contactMobile,
    required this.title,
    required this.description,
    required this.requestedDate,
    this.status = UpdationStatus.pending,
    this.value,
    this.deadline,
    this.assigneeId,
    this.assigneeName,
    this.attachments = const [],
    this.notes = '',
    this.followUp,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// UPD-0001 style ID.
  String get updationCode => codeFor(updationNumber);

  static String codeFor(int? n) =>
      n == null ? '-' : 'UPD-${n.toString().padLeft(4, '0')}';

  ProjectUpdationModel copyWith({
    String? uid,
    int? updationNumber,
    String? projectId,
    String? projectName,
    String? clientId,
    String? companyName,
    String? contactName,
    String? contactMobile,
    String? title,
    String? description,
    DateTime? requestedDate,
    UpdationStatus? status,
    double? value,
    DateTime? deadline,
    String? assigneeId,
    String? assigneeName,
    List<FileModel>? attachments,
    String? notes,
    String? followUp,
    bool clearFollowUp = false,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectUpdationModel(
      uid: uid ?? this.uid,
      updationNumber: updationNumber ?? this.updationNumber,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      contactMobile: contactMobile ?? this.contactMobile,
      title: title ?? this.title,
      description: description ?? this.description,
      requestedDate: requestedDate ?? this.requestedDate,
      status: status ?? this.status,
      value: value ?? this.value,
      deadline: deadline ?? this.deadline,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      followUp: clearFollowUp ? null : (followUp ?? this.followUp),
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'updationNumber': updationNumber,
    'projectId': projectId,
    'projectName': projectName,
    'clientId': clientId,
    'companyName': companyName,
    'contactName': contactName,
    'contactMobile': contactMobile,
    'title': title,
    'description': description,
    'requestedDate': requestedDate.millisecondsSinceEpoch,
    'status': status.name,
    'value': value,
    'deadline': deadline?.millisecondsSinceEpoch,
    'assigneeId': assigneeId,
    'assigneeName': assigneeName,
    'attachments': attachments.map((x) => x.toMap()).toList(),
    'notes': notes,
    'followUp': followUp,
    'createdBy': createdBy.toMap(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  /// Everything except the immutable ID, creator and creation time.
  Map<String, dynamic> toUpdateMap() {
    final data = toMap();
    data.remove('updationNumber');
    data.remove('createdBy');
    data.remove('createdAt');
    return data;
  }

  factory ProjectUpdationModel.fromMap(String uid, Map<String, dynamic> map) {
    String? str(String k) => map[k] is String ? map[k] as String : null;
    DateTime? date(String k) => map[k] is int
        ? DateTime.fromMillisecondsSinceEpoch(map[k] as int)
        : null;
    return ProjectUpdationModel(
      uid: uid,
      updationNumber: parseFirestoreInt(map['updationNumber']),
      projectId: str('projectId') ?? '',
      projectName: str('projectName') ?? '',
      clientId: str('clientId'),
      companyName: str('companyName'),
      contactName: str('contactName'),
      contactMobile: str('contactMobile'),
      title: str('title') ?? '',
      description: str('description') ?? '',
      requestedDate: date('requestedDate') ?? DateTime.now(),
      status: UpdationStatusX.fromName(str('status')),
      value: map['value'] is num ? (map['value'] as num).toDouble() : null,
      deadline: date('deadline'),
      assigneeId: str('assigneeId'),
      assigneeName: str('assigneeName'),
      attachments: map['attachments'] is List
          ? List<FileModel>.from(
              (map['attachments'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map((x) => FileModel.fromMap(x)),
            )
          : [],
      notes: str('notes') ?? '',
      followUp: (str('followUp') ?? '').isEmpty ? null : str('followUp'),
      createdBy: map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: date('createdAt') ?? DateTime.now(),
      updatedAt: date('updatedAt') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
}