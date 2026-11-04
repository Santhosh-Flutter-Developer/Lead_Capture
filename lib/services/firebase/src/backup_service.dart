import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '/services/services.dart';

class BackupTrigger {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  BackupTrigger({
    FirebaseFirestore? firestoreInstance,
    FirebaseStorage? storageInstance,
  }) : firestore = firestoreInstance ?? FirebaseFirestore.instance,
       storage = storageInstance ?? FirebaseStorage.instance;

  /// Backup a list of [paths]. Each path can be either:
  /// - a collection path: 'users' or '/users' or '/users/'
  /// - a document path: 'users/docId' or '/users/docId/' or deeper
  ///
  /// [subcollectionsMap] - optional map of collectionName -> list of subcollection
  /// names to recurse into for documents. Example: { 'posts': ['comments','likes'] }
  ///
  /// [fileName] - optional storage file name (defaults to backups/backup.json)
  ///
  /// Returns the uploaded file download URL.
  Future<String> backupPaths(
    List<String> paths, {
    Map<String, List<String>>? subcollectionsMap,
    String? fileName,
  }) async {
    final Map<String, dynamic> output = {};

    for (final rawPath in paths) {
      final normalized = _normalizePath(rawPath);
      if (normalized.isEmpty) continue;

      final segments = normalized.split('/');

      if (_isDocumentPath(segments)) {
        // Document path -> get that document and optionally its declared subcollections
        final docRef = _docRefFromSegments(segments);
        final docData = await _documentToMapRecursive(
          docRef,
          subcollectionsMap: subcollectionsMap,
        );
        // place the doc under its full path key to avoid collisions
        output[normalized] = docData;
      } else {
        // Collection path -> export entire collection
        final collectionName = segments.first;
        final colData = await _collectionToMap(
          collectionName,
          subcollectionsMap: subcollectionsMap,
        );
        output[collectionName] = colData;
      }
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(output);

    final now = DateTime.now().toUtc();
    final timestamp = now.toIso8601String().replaceAll(':', '-');
    final path = fileName ?? 'backups/backup-$timestamp.json';

    final ref = storage.ref().child(path);
    final bytes = utf8.encode(jsonString);

    await ref.putData(bytes, SettableMetadata(contentType: 'application/json'));
    String? url = await ref.getDownloadURL();

    Map<String, dynamic> docMap = {
      'intiatedBy': await Spdb.getUid(),
      'parentCollectionId': await Spdb.getCid(),
      'timestamp': now,
      'path': path,
      'size': bytes.length,
      'url': url,
      'type': 'export',
    };
    await firestore.collection('backups').add(docMap);
    return url;
  }

  // ---------------------- Helpers ----------------------

  String _normalizePath(String p) {
    var s = p.trim();
    if (s.startsWith('/')) s = s.substring(1);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  bool _isDocumentPath(List<String> segments) {
    // Firestore paths alternate collection/doc/collection/doc...
    // If segments length is even -> ends with doc id -> document path
    return segments.length % 2 == 0;
  }

  DocumentReference<Map<String, dynamic>> _docRefFromSegments(
    List<String> segments,
  ) {
    DocumentReference<Map<String, dynamic>> ref = firestore
        .doc(segments.join('/'))
        .withConverter(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (map, _) => map,
        );
    return ref;
  }

  CollectionReference<Map<String, dynamic>> _colRef(String collectionName) {
    return firestore
        .collection(collectionName)
        .withConverter(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (map, _) => map,
        );
  }

  /// Export a whole collection (shallow) and include specified subcollections
  /// for each document if [subcollectionsMap] contains entries for the collection
  Future<Map<String, dynamic>> _collectionToMap(
    String collectionName, {
    Map<String, List<String>>? subcollectionsMap,
  }) async {
    final Map<String, dynamic> result = {};

    final QuerySnapshot<Map<String, dynamic>> colSnap = await _colRef(
      collectionName,
    ).get();

    for (final doc in colSnap.docs) {
      final data = _documentDataToSerializable(doc.data());

      if (subcollectionsMap != null &&
          subcollectionsMap.containsKey(collectionName)) {
        final subNames = subcollectionsMap[collectionName]!;
        for (final subName in subNames) {
          final subMap = await _subcollectionsForDocument(
            doc.reference,
            subName,
            subcollectionsMap,
          );
          if (subMap.isNotEmpty) {
            data[subName] = subMap;
          }
        }
      }

      result[doc.id] = data;
    }

    return result;
  }

  /// Export a single document and recursively export any declared subcollections
  /// according to [subcollectionsMap].
  Future<Map<String, dynamic>> _documentToMapRecursive(
    DocumentReference<Map<String, dynamic>> docRef, {
    Map<String, List<String>>? subcollectionsMap,
  }) async {
    final snap = await docRef.get();
    if (!snap.exists) return {};

    final Map<String, dynamic> data = _documentDataToSerializable(
      snap.data() ?? {},
    );

    // Determine the collection name (the parent collection of this document)
    final parentCollection = _collectionNameFromDocRef(docRef.path);
    if (subcollectionsMap != null &&
        parentCollection != null &&
        subcollectionsMap.containsKey(parentCollection)) {
      final subNames = subcollectionsMap[parentCollection]!;
      for (final subName in subNames) {
        final subMap = await _subcollectionsForDocument(
          docRef,
          subName,
          subcollectionsMap,
        );
        if (subMap.isNotEmpty) data[subName] = subMap;
      }
    }

    return data;
  }

  String? _collectionNameFromDocRef(String docPath) {
    final parts = docPath.split('/');
    if (parts.length < 2) return null;
    // parent collection is the segment before the last id
    return parts[parts.length - 2];
  }

  Future<Map<String, dynamic>> _subcollectionsForDocument(
    DocumentReference<Map<String, dynamic>> docRef,
    String subcollectionName,
    Map<String, List<String>>? subcollectionsMap,
  ) async {
    final Map<String, dynamic> subResult = {};
    final QuerySnapshot<Map<String, dynamic>> subSnap = await docRef
        .collection(subcollectionName)
        .get();

    for (final sDoc in subSnap.docs) {
      final sData = _documentDataToSerializable(sDoc.data());

      if (subcollectionsMap != null &&
          subcollectionsMap.containsKey(subcollectionName)) {
        final nextSubNames = subcollectionsMap[subcollectionName]!;
        for (final nextName in nextSubNames) {
          final nested = await _subcollectionsForDocument(
            sDoc.reference,
            nextName,
            subcollectionsMap,
          );
          if (nested.isNotEmpty) {
            sData[nextName] = nested;
          }
        }
      }

      subResult[sDoc.id] = sData;
    }

    return subResult;
  }

  Map<String, dynamic> _documentDataToSerializable(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};

    data.forEach((key, value) {
      out[key] = _valueToSerializable(value);
    });

    return out;
  }

  dynamic _valueToSerializable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is GeoPoint) {
      return {
        '_type': 'geopoint',
        'lat': value.latitude,
        'lng': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return {'_type': 'reference', 'path': value.path};
    }
    if (value is Blob || value is Uint8List) {
      return {'_type': 'blob', 'length': (value as Uint8List).length};
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _valueToSerializable(v)));
    }
    if (value is List) return value.map(_valueToSerializable).toList();
    {
      return value;
    }
  }
}
