// import 'package:flutter/material.dart';
// import '/views/views.dart';
// import '/services/services.dart';

// class HiveData extends StatefulWidget {
//   const HiveData({super.key});

//   @override
//   State<HiveData> createState() => _HiveDataState();
// }

// class _HiveDataState extends State<HiveData> {
//   late Map<String, dynamic> _data;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadHiveData();
//   }

//   void _loadHiveData() {
//     setState(() {
//       _loading = true;
//     });

//     /// Get all hive data
//     final result = CacheService.getAllData();

//     setState(() {
//       _data = result;
//       _loading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: Back(),
//         title: Text("Hive Data Viewer"),
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHiveData),
//         ],
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _data.isEmpty
//           ? const Center(child: Text("No Hive data found"))
//           : ListView(
//               padding: const EdgeInsets.all(12),
//               children: _data.entries.map((box) {
//                 final boxName = box.key;
//                 final boxData = box.value as Map<String, dynamic>;

//                 return Card(
//                   elevation: 2,
//                   margin: const EdgeInsets.only(bottom: 12),
//                   child: ExpansionTile(
//                     title: Text(
//                       boxName,
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     children: [
//                       if (boxData.isEmpty)
//                         const Padding(
//                           padding: EdgeInsets.all(12),
//                           child: Text("No data in this box"),
//                         )
//                       else
//                         ...boxData.entries.map((entry) {
//                           return ListTile(
//                             dense: true,
//                             title: Text(
//                               entry.key,
//                               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                             subtitle: Text(entry.value.toString()),
//                           );
//                         }),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//     );
//   }
// }
