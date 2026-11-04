// import 'package:flutter/material.dart';
// import '/constants/constants.dart';
// import '/models/models.dart';
// import '/services/services.dart';
// import '/utils/utils.dart';

// class BankService {
//   static final FirebaseConfig firebase = FirebaseConfig();

//   static Future<void> createBank({
//     required BankModel bank,
//   }) async {
//     try {
//       var cid = await Spdb.getCid();
//       await CommonService.add(
//         '${Collections.users.name}/$cid/${Collections.banks.name}',
//         bank.toMap(),
//         activity: '${bank.bankName} has been added as a bank',
//       );
//     } catch (e, st) {
//       await ErrorService.recordError(e, st);
//       debugPrint("${e.toString()}, ${st.toString()}");
//       throw 'Error creating bank: $e';
//     }
//   }

//   static Future<void> editBank({
//     required String uid,
//     required BankModel bank,
//   }) async {
//     try {
//       var cid = await Spdb.getCid();
//       await CommonService.update(
//         '${Collections.users.name}/$cid/${Collections.banks.name}',
//         uid,
//         bank.toUpdateMap(),
//         activity: '${bank.bankName} has been updated',
//       );
//     } catch (e, st) {
//       await ErrorService.recordError(e, st);
//       debugPrint("${e.toString()}, ${st.toString()}");
//       throw 'Error updating bank: $e';
//     }
//   }

//   static Future<BankModel> getBank({required String uid}) async {
//     try {
//       var cid = await Spdb.getCid();
//       var bankDoc = await firebase.users
//           .doc(cid)
//           .collection(Collections.banks.name)
//           .doc(uid)
//           .get();

//       if (bankDoc.exists) {
//         var bankData = bankDoc.data();
//         if (bankData != null) {
//           return BankModel.fromMap(bankDoc.id, bankData);
//         } else {
//           throw 'Bank data is empty';
//         }
//       } else {
//         throw 'Bank not found';
//       }
//     } catch (e, st) {
//       await ErrorService.recordError(e, st);
//       debugPrint("${e.toString()}, ${st.toString()}");
//       throw 'Error fetching bank: $e';
//     }
//   }

//   static Future<List<BankModel>> getAllBanks() async {
//     try {
//       var cid = await Spdb.getCid();
//       var querySnapshot = await firebase.users
//           .doc(cid)
//           .collection(Collections.banks.name)
//           .get();

//       return querySnapshot.docs
//           .map((doc) => BankModel.fromMap(doc.id, doc.data()))
//           .toList();
//     } catch (e, st) {
//       await ErrorService.recordError(e, st);
//       debugPrint("${e.toString()}, ${st.toString()}");
//       throw 'Error fetching banks: $e';
//     }
//   }

//   static Future<void> deleteBank({required String uid}) async {
//     try {
//       var cid = await Spdb.getCid();

//       var docRef = await firebase.users
//           .doc(cid)
//           .collection(Collections.banks.name)
//           .doc(uid)
//           .get();

//       final data = docRef.data() as Map<String, dynamic>;
//       await TrashService.moveToTrash(
//         docRef: docRef.reference,
//         docData: data,
//         reason: 'user_deleted',
//       );
//       docRef.reference.delete();

//       var user = await Spdb.getUser();
//       ActivityLogModel activityLogModel = ActivityLogModel(
//         userData: user,
//         activity: '${data['bankName'].toString().decrypt} has been deleted',
//         description:
//             'User has deleted an entry in ${Collections.banks.name}',
//         collection:
//             '${Collections.users.name}/$cid/${Collections.banks.name}',
//         docId: docRef.id,
//       );
//       await CommonService.add(
//         '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
//         activityLogModel.toMap(),
//       );
//     } catch (e, st) {
//       await ErrorService.recordError(e, st);
//       debugPrint("${e.toString()}, ${st.toString()}");
//       throw e.toString();
//     }
//   }

//   static Future<void> restoreBank(BankModel bank) async {
//     var cid = await Spdb.getCid();

//     final uid = bank.uid;
//     if (uid == null || uid.isEmpty) {
//       throw Exception("UID missing");
//     }

//     await firebase.users
//         .doc(cid)
//         .collection(Collections.banks.name)
//         .doc(uid)
//         .set(bank.toMap());
//   }
// }
