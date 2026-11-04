import 'package:flutter/material.dart';
import 'lead_form.dart';

/// Edit Leads form. Same layout as create (see [LeadForm]).
class LeadEdit extends StatelessWidget {
  final String uid;
  const LeadEdit({super.key, required this.uid});

  @override
  Widget build(BuildContext context) => LeadForm(uid: uid);
}