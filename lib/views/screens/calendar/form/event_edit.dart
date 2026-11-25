import 'package:flutter/material.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import 'event_form_panel.dart';

/// "Edit Event" panel – loads the event, then shows [EventFormPanel].
class EventEdit extends StatefulWidget {
  final String uid;
  const EventEdit({super.key, required this.uid});

  @override
  State<EventEdit> createState() => _EventEditState();
}

class _EventEditState extends State<EventEdit> {
  late Future<EventModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<EventModel> _load() async {
    try {
      return await EventService.getEvent(uid: widget.uid);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: WaitingLoading());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          );
        }
        return EventFormPanel(initial: snapshot.data);
      },
    );
  }
}