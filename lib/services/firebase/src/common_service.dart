import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/models/models.dart';

class CommonService {
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // CommonService._(); // prevent instantiation

  /// Add a new document to [collectionPath].
  /// If [docId] is provided, document will be created with that id, otherwise
  /// Firestore will generate one and the generated DocumentReference is returned.
  ///
  /// Returns the created DocumentReference.
  static Future<DocumentReference<Map<String, dynamic>>> add(
    String collectionPath,
    Map<String, dynamic> values, {
    String? docId,
    String? activity,
    String? description,
    bool merge = false,
  }) async {
    try {
      final collection = firestore
          .collection(collectionPath)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (map, _) => map,
          );

      if (docId != null && docId.isNotEmpty) {
        final ref = collection.doc(docId);
        await ref.set(values, SetOptions(merge: merge));
        return ref;
      }

      final ref = await collection.add(values);

      if (activity != null) {
        var user = await Spdb.getUser();
        ActivityLogModel activityLogModel = ActivityLogModel(
          userData: user,
          activity: activity,
          description:
              description ??
              'User has added a entry on ${collectionPath.split('/').last}',
          collection: collectionPath,
          docId: ref.id,
        );

        AuthService.saveActivityLogs(log: activityLogModel);
      }

      return ref;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Update fields of an existing document. This only updates the provided
  /// fields; other fields remain untouched. Throws if document doesn't exist.
  static Future<void> update(
    String collectionPath,
    String docId,
    Map<String, dynamic> values, {
    String? activity,
    String? description,
  }) async {
    try {
      final ref = firestore.collection(collectionPath).doc(docId);
      if (activity != null) {
        var user = await Spdb.getUser();
        ActivityLogModel activityLogModel = ActivityLogModel(
          userData: user,
          activity: activity,
          description:
              description ??
              'User has updated a entry in ${collectionPath.split('/').last}',
          collection: collectionPath,
          docId: docId,
        );

        AuthService.saveActivityLogs(log: activityLogModel);
      }

      await ref.update(values);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Set (replace) a document. If [merge] is true it will merge fields.
  static Future<void> set(
    String collectionPath,
    String docId,
    Map<String, dynamic> values, {
    bool merge = false,
  }) async {
    try {
      final ref = firestore.collection(collectionPath).doc(docId);
      await ref.set(values, SetOptions(merge: merge));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Delete a document.
  static Future<void> delete(String collectionPath, String docId) async {
    try {
      final ref = firestore.collection(collectionPath).doc(docId);
      await ref.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Get single document snapshot (one-off).
  /// Returns null if document doesn't exist.
  static Future<DocumentSnapshot<Map<String, dynamic>>?> get(
    String collectionPath,
    String docId,
  ) async {
    try {
      final ref = firestore.collection(collectionPath).doc(docId);
      final snap = await ref.get();
      return snap.exists ? snap : null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Get all documents from a collection as a Future list.
  /// Optional [whereClauses] lets you pass simple equality filters.
  /// Example: getAll('users', whereClauses: { 'active': true })
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getAll(
    String collectionPath, {
    Map<String, dynamic>? whereClauses,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = firestore
          .collection(collectionPath)
          .withConverter(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (map, _) => map,
          );

      if (whereClauses != null) {
        whereClauses.forEach((field, value) {
          query = query.where(field, isEqualTo: value);
        });
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      if (limit != null) query = query.limit(limit);

      final snap = await query.get();
      return snap.docs;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Listen to changes in a collection and map to list of documents.
  /// Same optional query parameters as [getAll].
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamAll(
    String collectionPath, {
    Map<String, dynamic>? whereClauses,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    try {
      Query<Map<String, dynamic>> query = firestore
          .collection(collectionPath)
          .withConverter(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (map, _) => map,
          );

      if (whereClauses != null) {
        whereClauses.forEach((field, value) {
          query = query.where(field, isEqualTo: value);
        });
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      if (limit != null) query = query.limit(limit);

      return query.snapshots().map((s) => s.docs);
    } catch (e, st) {
      ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  /// Run a transaction with a callback. The callback receives the
  /// Transaction object and should return a Future.
  static Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler,
  ) async {
    return firestore.runTransaction<T>(transactionHandler);
  }

  /// Run a batched write.
  /// Example usage:
  /// final batch = CommonService.firestore.batch();
  /// final a = CommonService.firestore.collection('c').doc('a');
  /// batch.set(a, {'x':1});
  /// await CommonService.commitBatch(batch);
  static Future<void> commitBatch(WriteBatch batch) async {
    await batch.commit();
  }

  // ---------------------- Helper utilities ----------------------

  /// Convert a QueryDocumentSnapshot to a plain Map including id.
  static Map<String, dynamic> docToMap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = Map<String, dynamic>.from(doc.data());
    m['id'] = doc.id;
    return m;
  }

  /// Convert a DocumentSnapshot to a Map or null if not exists.
  static Map<String, dynamic>? snapToMap(
    DocumentSnapshot<Map<String, dynamic>>? snap,
  ) {
    if (snap == null || !snap.exists) return null;
    final m = Map<String, dynamic>.from(snap.data()!);
    m['id'] = snap.id;
    return m;
  }
}

class ErrorService {
  static FirebaseConfig firebase = FirebaseConfig();

  static Future<void> recordError(Object? e, StackTrace st) async {
    var cid = await Spdb.getCid();
    var uid = await Spdb.getUid();

    // Only log to Firestore if user is authenticated (has cid)
    // Skip during app initialization before authentication
    if (cid == null || cid.isEmpty) {
      return;
    }

    try {
      await firebase.errors.add({
        "error": e.toString(),
        "stackTrace": st.toString(),
        "time": DateTime.now(),
        "cid": cid,
        "uid": uid,
        "device": (await DeviceInfo.getDeviceInfo(forDebug: true)).toMatchMap(),
      });
    } catch (error) {
      // Silently ignore Firestore errors to prevent infinite error loops
      debugPrint("Failed to log error to Firestore: $error");
    }
  }
}
