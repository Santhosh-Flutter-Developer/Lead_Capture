// import 'package:flutter/material.dart';
// import '/services/services.dart';
// import '/models/models.dart';
// import '/views/views.dart';

// class BankCreate extends StatefulWidget {
//   const BankCreate({super.key});

//   @override
//   State<BankCreate> createState() => _BankCreateState();
// }

// class _BankCreateState extends State<BankCreate> {
//   final TextEditingController _shortCodeController = TextEditingController();
//   final TextEditingController _bankNameController = TextEditingController();
//   final TextEditingController _ifscCodeController = TextEditingController();
//   final TextEditingController _placeController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

//   @override
//   void dispose() {
//     _shortCodeController.dispose();
//     _bankNameController.dispose();
//     _ifscCodeController.dispose();
//     _placeController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ClipRRect(
//       borderRadius: const BorderRadius.only(
//         topLeft: Radius.circular(16),
//         bottomLeft: Radius.circular(16),
//       ),
//       child: Scaffold(
//         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//         body: Column(
//           children: [
//             FormWidgets.buildHeader(
//               context: context,
//               title: "Create Bank",
//             ),
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 16,
//                 ),
//                 child: ConstrainedBox(
//                   constraints: const BoxConstraints(minHeight: 500),
//                   child: Card(
//                     color: Theme.of(context).cardTheme.color,
//                     elevation: 7,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       side: BorderSide(
//                           color:
//                               Theme.of(context).colorScheme.outlineVariant),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 24.0,
//                         vertical: 24.0,
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Bank Information",
//                             style: Theme.of(context)
//                                 .textTheme
//                                 .titleMedium!
//                                 .copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   color:
//                                       Theme.of(context).colorScheme.primary,
//                                 ),
//                           ),
//                           const SizedBox(height: 10),
//                           Divider(
//                             color:
//                                 Theme.of(context).colorScheme.outlineVariant,
//                             thickness: 1,
//                           ),
//                           const SizedBox(height: 20),
//                           LayoutBuilder(
//                             builder: (context, constraints) =>
//                                 _buildFormFields(constraints),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         bottomNavigationBar: FormWidgets.buildBottomBar(
//           context: context,
//           onSubmit: _submitForm,
//           isEdit: false,
//         ),
//       ),
//     );
//   }

//   Widget _buildFormFields(BoxConstraints constraints) {
//     final double currentWidth = constraints.maxWidth;
//     const double horizontalSpacing = 16.0;
//     const double verticalSpacing = 8.0;
//     const double minColumnWidth = 220.0;

//     final bool canShowGrid =
//         currentWidth >= (minColumnWidth * 2 + horizontalSpacing);

//     final double itemWidth = canShowGrid
//         ? (currentWidth - horizontalSpacing) / 2
//         : currentWidth;

//     return Form(
//       key: _formKey,
//       child: Wrap(
//         spacing: horizontalSpacing,
//         runSpacing: verticalSpacing,
//         children: [
//           SizedBox(
//             width: itemWidth,
//             child: FormFields(
//               label: 'Short Code',
//               controller: _shortCodeController,
//               hintText: 'e.g. CNB, SBI',
//               isRequired: true,
//               valid: (input) => input == null || input.isEmpty
//                   ? 'Short Code is required'
//                   : null,
//             ),
//           ),
//           SizedBox(
//             width: itemWidth,
//             child: FormFields(
//               label: 'Bank Name',
//               controller: _bankNameController,
//               hintText: 'e.g. Canara Bank',
//               isRequired: true,
//               valid: (input) => input == null || input.isEmpty
//                   ? 'Bank Name is required'
//                   : null,
//             ),
//           ),
//           SizedBox(
//             width: itemWidth,
//             child: FormFields(
//               label: 'IFSC Code',
//               controller: _ifscCodeController,
//               hintText: 'e.g. CNRB0001016',
//               isRequired: true,
//               valid: (input) => input == null || input.isEmpty
//                   ? 'IFSC Code is required'
//                   : null,
//             ),
//           ),
//           SizedBox(
//             width: itemWidth,
//             child: FormFields(
//               label: 'Place',
//               controller: _placeController,
//               hintText: 'e.g. Sivakasi',
//               isRequired: true,
//               valid: (input) => input == null || input.isEmpty
//                   ? 'Place is required'
//                   : null,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _submitForm() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         futureLoading(context);
//         BankModel bankModel = BankModel(
//           shortCode: _shortCodeController.text.trim().toUpperCase(),
//           bankName: _bankNameController.text.trim(),
//           ifscCode: _ifscCodeController.text.trim().toUpperCase(),
//           place: _placeController.text.trim(),
//           createdBy: await Spdb.getUser(),
//         );

//         await BankService.createBank(bank: bankModel);

//         if (Navigator.canPop(context)) {
//           Navigator.pop(context);
//         }
//         Navigator.pop(context, true);

//         FlushBar.show(
//           context,
//           'Bank created successfully',
//           isSuccess: true,
//         );
//       } catch (e, st) {
//         await ErrorService.recordError(e, st);
//         debugPrint("${e.toString()}, ${st.toString()}");
//         if (Navigator.canPop(context)) {
//           Navigator.pop(context);
//         }
//         FlushBar.show(
//           context,
//           e.toString(),
//           isSuccess: false,
//           error: e,
//           stackTrace: st,
//         );
//       }
//     }
//   }
// }
