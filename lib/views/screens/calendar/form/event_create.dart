import 'package:flutter/material.dart';
import 'event_form_panel.dart';

/// "Add Event" panel. See [EventFormPanel] for the form itself.
class EventCreate extends StatelessWidget {
  final DateTime? selectedDate;
  const EventCreate({super.key, this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return EventFormPanel(selectedDate: selectedDate);
  }
}