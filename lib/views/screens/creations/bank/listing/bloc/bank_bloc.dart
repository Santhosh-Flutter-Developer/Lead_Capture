// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:equatable/equatable.dart';
// import '/services/services.dart';
// import '/constants/constants.dart';
// import '/models/models.dart';
// part 'bank_event.dart';
// part 'bank_state.dart';

// class BankBloc extends Bloc<BankEvent, BankState> {
//   FirebaseFirestore firestore = FirebaseFirestore.instance;
//   List<BankModel> allBanks = [];

//   BankBloc() : super(BankLoading()) {
//     on<StreamBanks>(_streamBanks);
//   }

//   Future<void> _streamBanks(
//       StreamBanks event, Emitter<BankState> emit) async {
//     emit(BankLoading());
//     var cid = await Spdb.getCid();

//     await emit.forEach(
//       firestore
//           .collection(Collections.users.name)
//           .doc(cid)
//           .collection(Collections.banks.name)
//           .snapshots()
//           .map((snapshot) {
//         allBanks = snapshot.docs
//             .map((doc) => BankModel.fromMap(doc.id, doc.data()))
//             .toList();
//         return allBanks;
//       }),
//       onData: (banks) => BankLoaded(banks),
//       onError: (error, stackTrace) {
//         return BankError("Failed to load banks, $error");
//       },
//     );
//   }
// }
