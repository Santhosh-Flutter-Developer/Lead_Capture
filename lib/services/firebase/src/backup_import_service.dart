// backup_import_service.dart
// Service to import a custom backup JSON (created by BackupTrigger.backupPaths)
// back into Firestore. Fixed: added class-level helper `_stripSubcollectionFields`
// so subcollection fields are removed from parent document data before writing.

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/services.dart';

class BackupImportService {
  final FirebaseFirestore firestore;
  final int _batchLimit = 400;

  BackupImportService({FirebaseFirestore? firestoreInstance})
    : firestore = firestoreInstance ?? FirebaseFirestore.instance;

  /// Import backup JSON from a local [file]. Pass the same [subcollectionsMap]
  /// you used for export so imports exactly mirror exports. If omitted the
  /// importer will still detect subcollection maps heuristically.
  Future<Map<String, dynamic>> importFromFile(
    File file, {
    Map<String, List<String>>? subcollectionsMap,
  }) async {
    final contents = await file.readAsString();
    return importFromJsonString(contents, subcollectionsMap: subcollectionsMap);
  }

  /// Import backup JSON from a JSON string. Pass [subcollectionsMap] to
  /// explicitly control which fields are treated as subcollections for each
  /// collection name.
  Future<Map<String, dynamic>> importFromJsonString(
    String jsonString, {
    Map<String, List<String>>? subcollectionsMap,
  }) async {
    final dynamic parsed = json.decode(jsonString);
    if (parsed is! Map<String, dynamic>) {
      throw ArgumentError('Backup JSON must be a top-level object');
    }

    WriteBatch batch = firestore.batch();
    int opCount = 0;
    int writtenDocs = 0;
    final List<String> warnings = [];

    Future<void> commitIfNeeded() async {
      if (opCount >= _batchLimit) {
        await batch.commit();
        batch = firestore.batch();
        opCount = 0;
      }
    }

    void batchSet(DocumentReference ref, Map<String, dynamic> data) {
      batch.set(ref, data, SetOptions(merge: true));
      opCount++;
      writtenDocs++;
    }

    for (final entry in parsed.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key.contains('/')) {
        // key is a document path (e.g. users/uid)
        if (value is Map<String, dynamic>) {
          final docPath = _normalizePath(key);

          // Determine parent collection name for subcollection extraction
          final parentCollection = _collectionNameFromDocRef(docPath);

          // Convert all fields (timestamps, geopoints, refs) first
          final convertedFull = _convertDocumentData(value, warnings: warnings);

          // Remove subcollection fields so they are not stored inside the parent doc
          final convertedForParent = _stripSubcollectionFields(
            convertedFull,
            parentCollection,
            subcollectionsMap: subcollectionsMap,
          );

          await commitIfNeeded();

          final ref = firestore.doc(docPath);
          batchSet(ref, convertedForParent);

          // Now import nested subcollection objects from the original value (not the stripped one)
          await _importNestedSubcollections(
            ref.path,
            value,
            subcollectionsMap: subcollectionsMap,
            batchSetter:
                (DocumentReference refChild, Map<String, dynamic> data) {
                  batchSet(refChild, data);
                },
            commitIfNeeded: commitIfNeeded,
            warnings: warnings,
          );
        } else {
          warnings.add('Document path $key has non-object value, skipped.');
        }
      } else {
        // key is a collection name; value expected to be { docId: docData }
        if (value is Map<String, dynamic>) {
          for (final docEntry in value.entries) {
            final docId = docEntry.key;
            final docValue = docEntry.value;
            if (docValue is! Map<String, dynamic>) {
              warnings.add(
                'Collection $key doc $docId has non-object value, skipped.',
              );
              continue;
            }

            final docPath = '$key/$docId';

            // Convert full document fields
            final convertedFull = _convertDocumentData(
              docValue,
              warnings: warnings,
            );

            // Remove subcollection fields before writing parent doc
            final convertedForParent = _stripSubcollectionFields(
              convertedFull,
              key,
              subcollectionsMap: subcollectionsMap,
            );

            await commitIfNeeded();

            final ref = firestore.doc(docPath);
            batchSet(ref, convertedForParent);

            // Import nested subcollections for this document using provided map
            await _importNestedSubcollections(
              ref.path,
              docValue,
              subcollectionsMap: subcollectionsMap,
              batchSetter:
                  (DocumentReference refChild, Map<String, dynamic> data) {
                    batchSet(refChild, data);
                  },
              commitIfNeeded: commitIfNeeded,
              warnings: warnings,
            );
          }
        } else {
          warnings.add(
            'Top-level collection $key has non-object value, skipped.',
          );
        }
      }

      if (opCount >= _batchLimit) {
        await batch.commit();
        batch = firestore.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    Map<String, dynamic> docMap = {
      'intiatedBy': await Spdb.getUid(),
      'parentCollectionId': await Spdb.getCid(),
      'timestamp': DateTime.now(),
      'result': {'writtenDocs': writtenDocs, 'warnings': warnings},
      'type': 'import',
    };
    await firestore.collection('backups').add(docMap);

    return {'writtenDocs': writtenDocs, 'warnings': warnings};
  }

  /// Remove fields from [docMap] that correspond to subcollections so that
  /// parent documents are written without nested subcollection objects. The
  /// [parentCollection] helps consult [subcollectionsMap] when provided.
  Map<String, dynamic> _stripSubcollectionFields(
    Map<String, dynamic> docMap,
    String? parentCollection, {
    Map<String, List<String>>? subcollectionsMap,
  }) {
    final result = Map<String, dynamic>.from(docMap);

    if (subcollectionsMap != null &&
        parentCollection != null &&
        subcollectionsMap.containsKey(parentCollection)) {
      final subs = subcollectionsMap[parentCollection]!;
      for (final sub in subs) {
        result.remove(sub);
      }
    } else {
      // heuristic: remove any field that looks like a subcollection map
      final keysToRemove = <String>[];
      result.forEach((k, v) {
        if (_looksLikeSubcollectionMap(v)) keysToRemove.add(k);
      });
      for (final k in keysToRemove) {
        result.remove(k);
      }
    }

    return result;
  }

  Future<void> _importNestedSubcollections(
    String parentDocPath,
    Map<String, dynamic> docData, {
    Map<String, List<String>>? subcollectionsMap,
    required void Function(
      DocumentReference refChild,
      Map<String, dynamic> data,
    )
    batchSetter,
    required Future<void> Function() commitIfNeeded,
    required List<String> warnings,
  }) async {
    for (final kv in docData.entries) {
      final key = kv.key;
      final val = kv.value;

      // Decide whether this field should be treated as subcollection
      final shouldTreatAsSubcollection =
          (subcollectionsMap != null &&
              subcollectionsMap.containsKey(
                _collectionNameFromDocRef(parentDocPath) ?? '',
              ))
          ? (subcollectionsMap[_collectionNameFromDocRef(parentDocPath) ?? '']!
                .contains(key))
          : _looksLikeSubcollectionMap(val);

      if (shouldTreatAsSubcollection && val is Map) {
        final subcollectionName = key;
        final Map<String, dynamic> subDocs = Map<String, dynamic>.from(val);

        for (final subEntry in subDocs.entries) {
          final subDocId = subEntry.key;
          final subDocVal = subEntry.value;

          if (subDocVal is! Map<String, dynamic>) {
            warnings.add(
              'Subcollection $subcollectionName doc $subDocId has non-object value, skipped.',
            );
            continue;
          }

          final childPath = '$parentDocPath/$subcollectionName/$subDocId';
          final childRef = firestore.doc(childPath);

          final convertedFull = _convertDocumentData(
            subDocVal,
            warnings: warnings,
          );

          // Strip any nested subcollection maps from this child before writing
          final convertedForParent = _stripSubcollectionFields(
            convertedFull,
            subcollectionName,
            subcollectionsMap: subcollectionsMap,
          );

          await commitIfNeeded();
          batchSetter(childRef, convertedForParent);

          // Recurse deeper to discover nested subcollections within this child document.
          await _importNestedSubcollections(
            childRef.path,
            subDocVal,
            subcollectionsMap: subcollectionsMap,
            batchSetter: batchSetter,
            commitIfNeeded: commitIfNeeded,
            warnings: warnings,
          );
        }
      }
    }
  }

  bool _looksLikeSubcollectionMap(dynamic val) {
    if (val is! Map) return false;
    if (val.isEmpty) return false;
    return val.values.every((v) => v is Map);
  }

  Map<String, dynamic> _convertDocumentData(
    Map<String, dynamic> raw, {
    required List<String> warnings,
  }) {
    final Map<String, dynamic> out = {};
    raw.forEach((k, v) {
      out[k] = _convertValueToFirestore(v, warnings: warnings, fieldPath: k);
    });
    return out;
  }

  dynamic _convertValueToFirestore(
    dynamic v, {
    required List<String> warnings,
    String? fieldPath,
  }) {
    if (v == null) return null;

    if (v is String) {
      DateTime? dt = _tryParseIso8601(v);
      dt ??= _tryParseNumericEpoch(v, warnings: warnings, fieldPath: fieldPath);
      if (dt != null) {
        try {
          if (_isDateTimeWithinTimestampRange(dt)) {
            return Timestamp.fromDate(dt.toUtc());
          } else {
            warnings.add(
              'DateTime out of Firestore Timestamp range for field ${fieldPath ?? ''}: ${dt.toIso8601String()}',
            );
            return dt.toIso8601String();
          }
        } catch (e) {
          warnings.add(
            'Failed to create Timestamp for field ${fieldPath ?? ''}: $e',
          );
          return dt.toIso8601String();
        }
      }
      return v;
    }

    if (v is Map<String, dynamic>) {
      if (v.containsKey('_type')) {
        final t = v['_type'];
        if (t == 'geopoint' && v.containsKey('lat') && v.containsKey('lng')) {
          return GeoPoint(
            (v['lat'] as num).toDouble(),
            (v['lng'] as num).toDouble(),
          );
        }
        if (t == 'reference' && v.containsKey('path')) {
          return firestore.doc(v['path']);
        }
        if (t == 'blob') {
          return null;
        }
      }
      final Map<String, dynamic> nested = {};
      v.forEach((k2, v2) {
        nested[k2] = _convertValueToFirestore(
          v2,
          warnings: warnings,
          fieldPath: (fieldPath != null ? '$fieldPath.$k2' : k2),
        );
      });
      return nested;
    }

    if (v is List) {
      return v
          .map(
            (e) => _convertValueToFirestore(
              e,
              warnings: warnings,
              fieldPath: fieldPath,
            ),
          )
          .toList();
    }

    return v;
  }

  DateTime? _tryParseIso8601(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  DateTime? _tryParseNumericEpoch(
    String s, {
    required List<String> warnings,
    String? fieldPath,
  }) {
    try {
      final n = int.parse(s);
      final abs = n.abs();
      if (abs >= 1000000000000000) {
        final ms = (n / 1000).round();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      if (abs >= 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      if (abs >= 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    } catch (e) {
      return null;
    }
  }

  bool _isDateTimeWithinTimestampRange(DateTime dt) {
    final millis = dt.toUtc().millisecondsSinceEpoch;
    const minMillis = -62135596800000; // year 0001
    const maxMillis = 253402300799000; // year 9999
    return millis >= minMillis && millis <= maxMillis;
  }

  String _normalizePath(String p) {
    var s = p.trim();
    if (s.startsWith('/')) s = s.substring(1);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  String? _collectionNameFromDocRef(String docPath) {
    final parts = _normalizePath(docPath).split('/');
    if (parts.length < 2) return null;
    return parts[parts.length - 2];
  }
}

/*
Usage example:

final importer = BackupImportService();
final file = File('/path/to/backup-2025-12-12.json');
final result = await importer.importFromFile(file, subcollectionsMap: {
  'users': ['activityLogs','admins','chats','clients','dealStatus','deals','departments','designations','employees','feed','leadCategory','leadStatus','leads','loginLogs','notifications','projects','roles','settings','subDepartments','tasks','trash','version'],
  'chats': ['messages'],
  'tasks': ['taskHistory','taskComments'],
});
print('Imported ${result['writtenDocs']} documents');
if ((result['warnings'] as List).isNotEmpty) print('Warnings: ${result['warnings']}');

Notes & extensions:
- This is safe for client use only when the signed-in account has permissions
  to write all target paths. For a full privileged import, run on a server
  using the Admin SDK.
- You can extend this to fetch and attach blobs saved separately in Storage.
- If you want a dry-run validation mode, we can add a flag to perform only
  parsing/validation without any writes.
*/
