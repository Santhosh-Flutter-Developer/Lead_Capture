import 'package:cloud_firestore/cloud_firestore.dart';

class TrashModel {
  final String originalPath;
  final String collection;
  final String documentId;
  final String parentPath;
  final Map<String, dynamic> data;
  final DateTime deletedAt;
  final String? deletedBy;
  final String? reason;
  final String canRestoreTo;

  TrashModel({
    required this.originalPath,
    required this.collection,
    required this.documentId,
    required this.parentPath,
    required this.data,
    required this.deletedAt,
    this.deletedBy,
    this.reason,
    required this.canRestoreTo,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalPath': originalPath,
      'collection': collection,
      'documentId': documentId,
      'parentPath': parentPath,
      'data': data,
      'deletedAt': Timestamp.fromDate(deletedAt),
      'deletedBy': deletedBy,
      'reason': reason,
      'canRestoreTo': canRestoreTo,
    };
  }

  factory TrashModel.fromMap(Map<String, dynamic> map) {
    return TrashModel(
      originalPath: map['originalPath'] as String,
      collection: map['collection'] as String,
      documentId: map['documentId'] as String,
      parentPath: map['parentPath'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
      deletedAt: (map['deletedAt'] as Timestamp).toDate(),
      deletedBy: map['deletedBy'] as String?,
      reason: map['reason'] as String?,
      canRestoreTo: map['canRestoreTo'] as String,
    );
  }
}
