import 'dart:convert';
import '/models/models.dart';

/// One payment allocation: part (or all) of a completed deal's value paid
/// into a Master Company with a payment mode. A deal can be split across
/// several allocations whose total never exceeds the deal value.
class PaymentModel {
  final String? uid;
  final String clientId;
  final String clientLabel; // "Company - Contact" snapshot for listing
  final String projectId; // deal uid
  final String projectName;
  final double dealValue;
  final String companyId; // master company uid
  final String companyName;
  final double allocatedValue;
  final String paymentMode;
  final String? upiNumber; // only when the payment mode is UPI
  final String? updationId; // optional completed Project Updation
  final String? updationLabel;
  final double updationValue;
  final List<FileModel> attachments;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    this.uid,
    required this.clientId,
    required this.clientLabel,
    required this.projectId,
    required this.projectName,
    required this.dealValue,
    required this.companyId,
    required this.companyName,
    required this.allocatedValue,
    required this.paymentMode,
    this.upiNumber,
    this.updationId,
    this.updationLabel,
    this.updationValue = 0,
    this.attachments = const [],
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  PaymentModel copyWith({
    String? uid,
    String? clientId,
    String? clientLabel,
    String? projectId,
    String? projectName,
    double? dealValue,
    String? companyId,
    String? companyName,
    double? allocatedValue,
    String? paymentMode,
    String? upiNumber,
    String? updationId,
    String? updationLabel,
    double? updationValue,
    List<FileModel>? attachments,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PaymentModel(
    uid: uid ?? this.uid,
    clientId: clientId ?? this.clientId,
    clientLabel: clientLabel ?? this.clientLabel,
    projectId: projectId ?? this.projectId,
    projectName: projectName ?? this.projectName,
    dealValue: dealValue ?? this.dealValue,
    companyId: companyId ?? this.companyId,
    companyName: companyName ?? this.companyName,
    allocatedValue: allocatedValue ?? this.allocatedValue,
    paymentMode: paymentMode ?? this.paymentMode,
    upiNumber: upiNumber ?? this.upiNumber,
    updationId: updationId ?? this.updationId,
    updationLabel: updationLabel ?? this.updationLabel,
    updationValue: updationValue ?? this.updationValue,
    attachments: attachments ?? this.attachments,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'clientLabel': clientLabel,
    'projectId': projectId,
    'projectName': projectName,
    'dealValue': dealValue,
    'companyId': companyId,
    'companyName': companyName,
    'allocatedValue': allocatedValue,
    'paymentMode': paymentMode,
    'upiNumber': upiNumber,
    'updationId': updationId,
    'updationLabel': updationLabel,
    'updationValue': updationValue,
    'attachments': attachments.map((x) => x.toMap()).toList(),
    'createdBy': createdBy.toMap(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PaymentModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime ts(dynamic v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v) : DateTime.now();
    double num_(dynamic v) => v is num ? v.toDouble() : 0.0;
    return PaymentModel(
      uid: uid,
      clientId: (map['clientId'] ?? '') as String,
      clientLabel: (map['clientLabel'] ?? '') as String,
      projectId: (map['projectId'] ?? '') as String,
      projectName: (map['projectName'] ?? '') as String,
      dealValue: num_(map['dealValue']),
      companyId: (map['companyId'] ?? '') as String,
      companyName: (map['companyName'] ?? '') as String,
      allocatedValue: num_(map['allocatedValue']),
      paymentMode: (map['paymentMode'] ?? '') as String,
      upiNumber: map['upiNumber'] as String?,
      updationId: map['updationId'] as String?,
      updationLabel: map['updationLabel'] as String?,
      updationValue: num_(map['updationValue']),
      attachments: map['attachments'] is List
          ? (map['attachments'] as List)
                .whereType<Map>()
                .map((e) => FileModel.fromMap(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      createdBy: map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: ts(map['createdAt']),
      updatedAt: ts(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());
}

/// All payment allocations of one project (deal), shown as a single row.
class PaymentGroup {
  final String projectId;
  final List<PaymentModel> lines;
  PaymentGroup(this.projectId, this.lines);

  PaymentModel get first => lines.first;
  String get uid => projectId;
  String get clientId => first.clientId;
  String get clientLabel => first.clientLabel;
  String get projectName => first.projectName;
  double get dealValue => first.dealValue;
  UserDataModel get createdBy => first.createdBy;
  double get allocatedValue =>
      lines.fold(0.0, (sum, l) => sum + l.allocatedValue);
  /// Total value of the distinct project updations used by these lines.
  double get updationsTotal {
    final seen = <String, double>{};
    for (final l in lines) {
      if ((l.updationId ?? '').isNotEmpty) seen[l.updationId!] = l.updationValue;
    }
    return seen.values.fold(0.0, (a, b) => a + b);
  }

  /// Deal value plus the allocated project updations' value.
  double get totalValue => dealValue + updationsTotal;
  List<String> get modes => _distinct(lines.map((l) => l.paymentMode));
  List<String> get companies => _distinct(lines.map((l) => l.companyName));
  String get modesText => modes.join(', ');
  String get companiesText => companies.join(', ');
  DateTime get createdAt => lines
      .map((l) => l.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  static List<String> _distinct(Iterable<String> v) =>
      v.where((e) => e.trim().isNotEmpty).toSet().toList();

  /// Groups payment lines by project, newest first.
  static List<PaymentGroup> group(List<PaymentModel> all) {
    final map = <String, List<PaymentModel>>{};
    for (final p in all) {
      map.putIfAbsent(p.projectId, () => []).add(p);
    }
    final groups = [
      for (final e in map.entries)
        PaymentGroup(
          e.key,
          e.value..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        ),
    ];
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return groups;
  }
}