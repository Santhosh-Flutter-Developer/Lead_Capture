// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:leadcapture/constants/src/enum.dart';

import '/models/models.dart';

class LeadModel {
  final String? uid;
  final int? leadNumber;
  final String? salutation;
  final String leadName;
  final String leadEmail;
  final LeadSourceModel leadSource;
  final String leadCategory;
  final String leadPriority;
  final double leadValue;
  // final bool allowFollowUp;
  final String leadStatus;
  // final String leadSubStatus;
  final List<FileModel> attachments;
  final String notes;
  final String? companyName;
  final String? companyWebsite;
  final String? companyMobile;
  final RegionModel? companyCountry;
  final StateModel? companyState;
  final CityModel? companyCity;
  final String? companyAddress;
  final String? companyZipCode;
  final String? clientName;
  final String? clientEmail;
  final String? clientMobile;
  final String? clientGender;
  final UserDataModel createdBy;
  final List<String> workflow;
  final String? clientId;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool leadsConverted;
  final String? dealId;
  final String? projectName;
  final String? projectDescription;
  /// Employee (uid) responsible for the follow-up. When set, only this
  /// employee and admins can see the record. `null` = visible as before.
  final String? followUp;

  LeadModel({
    this.uid,
    this.leadNumber,
    this.salutation,
    required this.leadName,
    required this.leadEmail,
    required this.leadSource,
    required this.leadCategory,
    required this.leadPriority,
    required this.leadValue,
    // required this.allowFollowUp,
    required this.leadStatus,
    required this.attachments,
    required this.notes,
    this.companyName,
    this.companyWebsite,
    this.companyMobile,
    this.companyCountry,
    this.companyState,
    this.companyCity,
    this.companyAddress,
    this.companyZipCode,
    this.clientName,
    this.clientEmail,
    this.clientGender,
    this.clientMobile,
    required this.createdBy,
    this.workflow = const [],
    this.clientId,
    this.dealId,
    this.projectName,
    this.projectDescription,
    this.followUp,
    this.leadsConverted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  LeadModel copyWith({
    String? uid,
    int? leadNumber,
    String? salutation,
    String? leadName,
    String? leadEmail,
    LeadSourceModel? leadSource,
    String? leadCategory,
    String? leadPriority,
    double? leadValue,
    // bool? allowFollowUp,
    String? leadStatus,
    List<FileModel>? attachments,
    String? notes,
    String? companyName,
    String? companyWebsite,
    String? companyMobile,
    RegionModel? companyCountry,
    StateModel? companyState,
    CityModel? companyCity,
    String? companyAddress,
    String? companyZipCode,
    String? clientName,
    String? clientEmail,
    String? clientMobile,
    String? clientGender,
    List<String>? workflow,
    String? clientId,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? leadsConverted,
    String? dealId,
    String? projectName,
    String? projectDescription,
    String? followUp,
    bool clearFollowUp = false,
  }) {
    return LeadModel(
      uid: uid ?? this.uid,
      leadNumber: leadNumber ?? this.leadNumber,
      salutation: salutation ?? this.salutation,
      leadName: leadName ?? this.leadName,
      leadEmail: leadEmail ?? this.leadEmail,
      leadSource: leadSource ?? this.leadSource,
      leadCategory: leadCategory ?? this.leadCategory,
      leadPriority: leadPriority ?? this.leadPriority,
      leadValue: leadValue ?? this.leadValue,
      // allowFollowUp: allowFollowUp ?? this.allowFollowUp,
      leadStatus: leadStatus ?? this.leadStatus,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      companyName: companyName ?? this.companyName,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyMobile: companyMobile ?? this.companyMobile,
      companyCountry: companyCountry ?? this.companyCountry,
      companyState: companyState ?? this.companyState,
      companyCity: companyCity ?? this.companyCity,
      companyAddress: companyAddress ?? this.companyAddress,
      companyZipCode: companyZipCode ?? this.companyZipCode,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientMobile: clientMobile ?? this.clientMobile,
      clientGender: clientGender ?? this.clientGender,
      workflow: workflow ?? this.workflow,
      clientId: clientId ?? this.clientId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      leadsConverted: leadsConverted ?? this.leadsConverted,
      dealId: dealId ?? this.dealId,
      projectName: projectName ?? this.projectName,
      projectDescription: projectDescription ?? this.projectDescription,
      followUp: clearFollowUp ? null : (followUp ?? this.followUp),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'leadNumber': leadNumber,
      'salutation': salutation,
      'leadName': leadName,
      'leadEmail': leadEmail,
      'leadSource': leadSource.toStoreMap(),
      'leadCategory': leadCategory,
      'leadPriority': leadPriority,
      'leadValue': leadValue,
      // 'allowFollowUp': allowFollowUp,
      'leadStatus': leadStatus,
      'attachments': attachments.map((x) => x.toMap()).toList(),
      'notes': notes,
      'companyName': companyName,
      'companyWebsite': companyWebsite,
      'companyMobile': companyMobile,
      'companyCountry': companyCountry?.toMap(),
      'companyState': companyState?.toMap(),
      'companyCity': companyCity?.toMap(),
      'companyAddress': companyAddress,
      'companyZipCode': companyZipCode,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientMobile': clientMobile,
      'clientGender': clientGender,
      'workflow': workflow,
      'clientId': clientId,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'leadsConverted': leadsConverted,
      'dealId': dealId,
      'projectName': projectName,
      'projectDescription': projectDescription,
      'followUp': followUp,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    final data = {
      'uid': uid,
      'leadNumber': leadNumber,
      'salutation': salutation,
      'leadName': leadName,
      'leadEmail': leadEmail,
      'leadSource': leadSource.toStoreMap(),
      'leadCategory': leadCategory,
      'leadPriority': leadPriority,
      'leadValue': leadValue,
      // 'allowFollowUp': allowFollowUp,
      'leadStatus': leadStatus,
      'attachments': attachments.map((x) => x.toMap()).toList(),
      'notes': notes,
      'companyName': companyName,
      'companyWebsite': companyWebsite,
      'companyMobile': companyMobile,
      'companyCountry': companyCountry?.toMap(),
      'companyState': companyState?.toMap(),
      'companyCity': companyCity?.toMap(),
      'companyAddress': companyAddress,
      'companyZipCode': companyZipCode,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientMobile': clientMobile,
      'clientGender': clientGender,
      'workflow': workflow,
      'clientId': clientId,
      'createdBy': createdBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'leadsConverted': leadsConverted,
      'dealId': dealId,
      'projectName': projectName,
      'projectDescription': projectDescription,
      'followUp': followUp,
    };
    data.removeWhere(
      (key, value) =>
          value == null &&
          (key == 'uid' || key == 'leadNumber' || key == 'dealId'),
    );
    return data;
  }

  factory LeadModel.fromMap(String uid, Map<String, dynamic> map) {
    return LeadModel(
      uid: uid,
      leadNumber: parseFirestoreInt(map['leadNumber']),
      salutation: map['salutation'] != null && map['salutation'] is String
          ? map['salutation'] as String
          : null,
      leadName: map['leadName'] is String ? map['leadName'] as String : '',
      leadEmail: map['leadEmail'] is String ? map['leadEmail'] as String : '',
      leadSource:
          map['leadSource'] != null && map['leadSource'] is Map<String, dynamic>
          ? LeadSourceModel.fromMap(
              map['leadSource']['uid'],
              map['leadSource'] as Map<String, dynamic>,
            )
          : LeadSourceModel.fromEmptyMap(),
      leadCategory: map['leadCategory'] is String
          ? map['leadCategory'] as String
          : '',
      leadPriority: map['leadPriority'] is String
          ? map['leadPriority'] as String
          : '',
      leadStatus: map['leadStatus'] is String
          ? map['leadStatus'] as String
          : '',
      leadValue: map['leadValue'] is num
          ? (map['leadValue'] as num).toDouble()
          : double.tryParse(map['leadValue']?.toString() ?? '0') ?? 0.0,
      // allowFollowUp: map['allowFollowUp'] is bool
      //     ? map['allowFollowUp'] as bool
      //     : false,
      attachments: map['attachments'] != null && map['attachments'] is List
          ? List<FileModel>.from(
              (map['attachments'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map((x) => FileModel.fromMap(x)),
            )
          : [],
      notes: map['notes'] is String ? map['notes'] as String : '',
      companyName: map['companyName'] != null && map['companyName'] is String
          ? map['companyName'] as String
          : null,
      companyWebsite:
          map['companyWebsite'] != null && map['companyWebsite'] is String
          ? map['companyWebsite'] as String
          : null,
      companyMobile:
          map['companyMobile'] != null && map['companyMobile'] is String
          ? map['companyMobile'] as String
          : null,
      companyCountry:
          map['companyCountry'] != null &&
              map['companyCountry'] is Map<String, dynamic>
          ? RegionModel.fromRefMap(
              map['companyCountry'] as Map<String, dynamic>,
            )
          : null,
      companyState:
          map['companyState'] != null &&
              map['companyState'] is Map<String, dynamic>
          ? StateModel.fromMap(map['companyState'] as Map<String, dynamic>)
          : null,
      companyCity:
          map['companyCity'] != null &&
              map['companyCity'] is Map<String, dynamic>
          ? CityModel.fromMap(map['companyCity'] as Map<String, dynamic>)
          : null,
      companyAddress:
          map['companyAddress'] != null && map['companyAddress'] is String
          ? map['companyAddress'] as String
          : null,
      companyZipCode:
          map['companyZipCode'] != null && map['companyZipCode'] is String
          ? map['companyZipCode'] as String
          : null,
      clientName: map['clientName'] != null && map['clientName'] is String
          ? map['clientName'] as String
          : null,
      clientEmail: map['clientEmail'] != null && map['clientEmail'] is String
          ? map['clientEmail'] as String
          : null,
      clientMobile: map['clientMobile'] != null && map['clientMobile'] is String
          ? map['clientMobile'] as String
          : null,
      clientGender: map['clientGender'] != null && map['clientGender'] is String
          ? map['clientGender'] as String
          : null,
      createdBy:
          map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      workflow: map['workflow'] != null && map['workflow'] is List
          ? List<String>.from(map['workflow'])
          : [],
      clientId: map['clientId'] != null && map['clientId'] is String
          ? map['clientId'] as String
          : null,
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      leadsConverted:
          map['leadsConverted'] != null && map['leadsConverted'] is bool
          ? map['leadsConverted'] as bool
          : false,
      dealId: map['dealId'] != null && map['dealId'] is String
          ? map['dealId'] as String
          : null,
      projectName: map['projectName'] is String
          ? map['projectName'] as String
          : null,
      projectDescription: map['projectDescription'] is String
          ? map['projectDescription'] as String
          : null,
      followUp: map['followUp'] is String && (map['followUp'] as String).isNotEmpty
          ? map['followUp'] as String
          : null,
    );
  }

  factory LeadModel.quick({
    required String leadName,
    required double leadValue,
    required String leadStatus,
    required UserDataModel createdBy,
    List<String> workflow = const [],
    LeadSourceModel? leadSource,
    String? companyName,
    String? companyWebsite,
    String? companyMobile,
    RegionModel? companyCountry,
    StateModel? companyState,
    CityModel? companyCity,
    String? companyAddress,
    String? companyZipCode,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientMobile,
    String? clientGender,
    String? salutation,
    String? projectName,
  }) {
    return LeadModel(
      uid: null,
      leadNumber: null,
      salutation: salutation,
      leadName: leadName,
      leadValue: leadValue,
      leadStatus: leadStatus,
      leadEmail: '',
      leadSource: leadSource ?? LeadSourceModel.fromEmptyMap(),
      leadCategory: '',
      leadPriority: '',
      // allowFollowUp: true,
      attachments: const [],
      notes: '',
      companyName: companyName,
      companyWebsite: companyWebsite,
      companyMobile: companyMobile,
      companyCountry: companyCountry,
      companyState: companyState,
      companyCity: companyCity,
      companyAddress: companyAddress,
      companyZipCode: companyZipCode,
      clientEmail: clientEmail,
      clientGender: clientGender,
      clientMobile: clientMobile,
      clientName: clientName,
      createdBy: createdBy,
      workflow: workflow,
      clientId: clientId,
      projectName: projectName,
      dealId: null,
      leadsConverted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory LeadModel.fromJson(String uid, String source) =>
      LeadModel.fromMap(uid, json.decode(source));

  @override
  String toString() =>
      'LeadModel(uid: $uid, leadName: $leadName, leadEmail: $leadEmail, leadCategory: $leadCategory, leadStatus: $leadStatus)';

  @override
  bool operator ==(covariant LeadModel other) {
    if (identical(this, other)) return true;
    return other.uid == uid &&
        other.leadName == leadName &&
        other.leadEmail == leadEmail &&
        other.leadCategory == leadCategory &&
        other.leadStatus == leadStatus;
  }

  @override
  int get hashCode =>
      Object.hash(uid, leadName, leadEmail, leadCategory, leadStatus);
}

class LeadCommentModel {
  final String? uid;
  final String userId;
  final String comment;
  final List<FileModel> attachments;
  final UserDataModel createdBy;
  final DateTime timestamp;

  LeadCommentModel({
    this.uid,
    required this.userId,
    required this.comment,
    this.attachments = const [],
    required this.createdBy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  LeadCommentModel copyWith({
    String? userId,
    String? comment,
    List<FileModel>? attachments,
    UserDataModel? createdBy,
    DateTime? timestamp,
  }) {
    return LeadCommentModel(
      userId: userId ?? this.userId,
      comment: comment ?? this.comment,
      attachments: attachments ?? this.attachments,
      createdBy: createdBy ?? this.createdBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'comment': comment,
    'attachments': attachments.map((x) => x.toMap()).toList(),
    'createdBy': createdBy.toMap(),
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory LeadCommentModel.fromMap(Map<String, dynamic> map) =>
      LeadCommentModel(
        uid: map['uid'] is String ? map['uid'] as String : null,
        userId: map['userId'] as String,
        comment: map['comment'] as String,
        attachments: map['attachments'] != null && map['attachments'] is List
            ? List<FileModel>.from(
                (map['attachments'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map((x) => FileModel.fromMap(x)),
              )
            : [],
        createdBy:
            map['createdBy'] != null && map['createdBy'] is Map<String, dynamic>
            ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
            : UserDataModel.fromEmptyMap(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}

class LeadHistoryModel {
  final String userId;
  final String updateDisposition;
  final String? update;
  final DateTime timestamp;

  LeadHistoryModel({
    required this.userId,
    required this.updateDisposition,
    this.update,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  LeadHistoryModel copyWith({
    String? userId,
    String? updateDisposition,
    String? update,
    DateTime? timestamp,
  }) {
    return LeadHistoryModel(
      userId: userId ?? this.userId,
      updateDisposition: updateDisposition ?? this.updateDisposition,
      update: update ?? this.update,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'updateDisposition': updateDisposition,
    'update': update,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory LeadHistoryModel.fromMap(Map<String, dynamic> map) =>
      LeadHistoryModel(
        userId: map['userId'] as String,
        updateDisposition: map['updateDisposition'] as String,
        update: map['update'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}

class LeadActivityModel {
  final String? uid;
  final String title;
  final String description;
  final LeadActivityType type;
  final DateTime scheduledAt;
  final String createdBy;
  final DateTime createdAt;
  final bool completed;

  LeadActivityModel({
    this.uid,
    required this.title,
    required this.description,
    required this.type,
    required this.scheduledAt,
    required this.createdBy,
    required this.createdAt,
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
    "title": title,
    "description": description,
    "type": type.name,
    "scheduledAt": scheduledAt.millisecondsSinceEpoch,
    "createdBy": createdBy,
    "createdAt": createdAt.millisecondsSinceEpoch,
    "completed": completed,
  };

  factory LeadActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return LeadActivityModel(
      uid: id,
      title: map["title"],
      description: map["description"],
      type: LeadActivityType.values.byName(map["type"]),
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(map["scheduledAt"]),
      createdBy: map["createdBy"],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map["createdAt"]),
      completed: map["completed"] ?? false,
    );
  }
}