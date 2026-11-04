import 'package:flutter/material.dart';
import 'deal_form.dart';

/// Edit Deals form. Same layout as create (see [DealForm]).
class DealEdit extends StatelessWidget {
  final String uid;
  const DealEdit({super.key, required this.uid});

  @override
  Widget build(BuildContext context) => DealForm(uid: uid);
}