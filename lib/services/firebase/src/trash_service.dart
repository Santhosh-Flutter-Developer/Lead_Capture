import 'package:cloud_firestore/cloud_firestore.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class TrashService {
  static Future<void> moveToTrash({
    required DocumentReference docRef,
    required Map<String, dynamic> docData,
    String? reason,
  }) async {
    var cid = await Spdb.getCid();
    var uid = await Spdb.getUid();

    final firestore = FirebaseFirestore.instance;

    final originalPath = docRef.path;
    final segments = docRef.path.split('/');
    final documentId = docRef.id;
    final collection = segments.length >= 2
        ? segments[segments.length - 2]
        : '';
    final parentPath = segments.length > 2
        ? segments.sublist(0, segments.length - 2).join('/')
        : '';

    final trashEntry = TrashModel(
      originalPath: originalPath,
      collection: collection,
      documentId: documentId,
      parentPath: parentPath,
      data: docData,
      deletedAt: DateTime.now(),
      deletedBy: uid,
      reason: reason,
      canRestoreTo: originalPath,
    );

    final trashRef = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.trash.name)
        .doc();

    final batch = firestore.batch();
    batch.set(trashRef, trashEntry.toMap());
    batch.delete(docRef);

    await batch.commit();
  }

  static Future<void> restoreFromTrash(String trashId) async {
    var cid = await Spdb.getCid();

    final firestore = FirebaseFirestore.instance;
    final snapRef = await firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.trash.name)
        .doc(trashId)
        .get();
    if (!snapRef.exists) return;

    final data = snapRef.data() as Map<String, dynamic>;
    final entry = TrashModel.fromMap(data);

    final originalDocRef = firestore.doc(entry.canRestoreTo);

    final batch = firestore.batch();
    batch.set(originalDocRef, entry.data, SetOptions(merge: false));
    batch.delete(snapRef.reference);

    await batch.commit();
  }
}
