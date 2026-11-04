// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:iconsax/iconsax.dart';
// import '/services/services.dart';
// import '/utils/utils.dart';
// import '/views/ui/src/flush_bar.dart';
// import '/views/ui/src/form_fields.dart';
// import '/views/ui/src/loading.dart';

// class CompanyLocationSettings extends StatefulWidget {
//   const CompanyLocationSettings({super.key});

//   @override
//   State<CompanyLocationSettings> createState() =>
//       _CompanyLocationSettingsState();
// }

// class _CompanyLocationSettingsState extends State<CompanyLocationSettings> {
//   final _formKey = GlobalKey<FormState>();
//   final _latCtrl = TextEditingController();
//   final _lngCtrl = TextEditingController();
//   final _radiusCtrl = TextEditingController();
//   bool _loading = true;
//   bool _detectingLocation = false;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   @override
//   void dispose() {
//     _latCtrl.dispose();
//     _lngCtrl.dispose();
//     _radiusCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _load() async {
//     final geofence = await CompanyLocationService.getGeofence();
//     if (geofence != null) {
//       _latCtrl.text = geofence.latitude.toStringAsFixed(6);
//       _lngCtrl.text = geofence.longitude.toStringAsFixed(6);
//       _radiusCtrl.text = geofence.radiusMeters.toStringAsFixed(0);
//     } else {
//       _radiusCtrl.text = '100';
//     }
//     setState(() => _loading = false);
//   }

//   Future<void> _detectLocation() async {
//     setState(() => _detectingLocation = true);
//     try {
//       final position = await LocationService.getCurrentPosition();
//       if (position == null) {
//         if (mounted) {
//           FlushBar.show(
//             context,
//             'Location permission denied or service unavailable.',
//             isSuccess: false,
//           );
//         }
//         return;
//       }
//       _latCtrl.text = position.latitude.toStringAsFixed(6);
//       _lngCtrl.text = position.longitude.toStringAsFixed(6);
//       if (mounted) setState(() {});
//     } catch (e) {
//       if (mounted) {
//         FlushBar.show(
//           context,
//           'Failed to detect location: $e',
//           isSuccess: false,
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _detectingLocation = false);
//     }
//   }

//   Future<void> _save() async {
//     if (!_formKey.currentState!.validate()) return;
//     final lat = double.tryParse(_latCtrl.text.trim());
//     final lng = double.tryParse(_lngCtrl.text.trim());
//     final radius = double.tryParse(_radiusCtrl.text.trim());
//     if (lat == null || lng == null || radius == null) {
//       FlushBar.show(context, 'Invalid values. Please check inputs.',
//           isSuccess: false);
//       return;
//     }
//     try {
//       futureLoading(context);
//       await CompanyLocationService.saveGeofence(
//         latitude: lat,
//         longitude: lng,
//         radiusMeters: radius,
//       );
//       if (mounted) Navigator.pop(context);
//       FlushBar.show(context, 'Company location saved.', isSuccess: true);
//     } catch (e) {
//       if (mounted) Navigator.pop(context);
//       FlushBar.show(context, e.toString(), isSuccess: false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Company Location'),
//         actions: [
//           TextButton(
//             onPressed: _loading ? null : _save,
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _info(),
//                     const SizedBox(height: 24),
//                     _label('Latitude'),
//                     _numericField(_latCtrl, 'e.g. 9.441321', required: true),
//                     const SizedBox(height: 16),
//                     _label('Longitude'),
//                     _numericField(_lngCtrl, 'e.g. 77.796719', required: true),
//                     const SizedBox(height: 16),
//                     _label('Allowed Radius (metres)'),
//                     _numericField(
//                       _radiusCtrl,
//                       'e.g. 100',
//                       required: true,
//                       positiveOnly: true,
//                     ),
//                     const SizedBox(height: 24),
//                     if (kIsMobile)
//                       SizedBox(
//                         width: double.infinity,
//                         child: OutlinedButton.icon(
//                           onPressed:
//                               _detectingLocation ? null : _detectLocation,
//                           icon: _detectingLocation
//                               ? const SizedBox(
//                                   width: 16,
//                                   height: 16,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                   ),
//                                 )
//                               : const Icon(Iconsax.gps, size: 18),
//                           label: Text(
//                             _detectingLocation
//                                 ? 'Detecting...'
//                                 : 'Use Current Device Location',
//                           ),
//                           style: OutlinedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _info() {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.blue.withValues(alpha: 0.07),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
//       ),
//       child: const Row(
//         children: [
//           Icon(Iconsax.info_circle, size: 18, color: Colors.blue),
//           SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               'Employees on mobile can only clock in when they are within '
//               'the allowed radius of the company\'s GPS coordinates.',
//               style: TextStyle(fontSize: 13, color: Colors.blue),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _label(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Text(
//         text,
//         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
//       ),
//     );
//   }

//   Widget _numericField(
//     TextEditingController controller,
//     String hint, {
//     bool required = false,
//     bool positiveOnly = false,
//   }) {
//     return FormFields(
//       controller: controller,
//       hintText: hint,
//       keyboardType: const TextInputType.numberWithOptions(
//         signed: true,
//         decimal: true,
//       ),
//       inputFormatters: [
//         FilteringTextInputFormatter.allow(
//           positiveOnly ? RegExp(r'[0-9.]') : RegExp(r'[-0-9.]'),
//         ),
//       ],
//       valid: required
//           ? (v) {
//               if (v == null || v.trim().isEmpty) return 'Required';
//               if (double.tryParse(v.trim()) == null) return 'Invalid number';
//               if (positiveOnly && (double.tryParse(v.trim()) ?? 0) <= 0) {
//                 return 'Must be greater than 0';
//               }
//               return null;
//             }
//           : null,
//     );
//   }
// }
