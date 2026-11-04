import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EventEdit extends StatefulWidget {
  final String uid;
  const EventEdit({super.key, required this.uid});

  @override
  State<EventEdit> createState() => _EventEditState();
}

class _EventEditState extends State<EventEdit> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventDescriptionController =
      TextEditingController();
  final TextEditingController _eventDateTimeController =
      TextEditingController();
  final TextEditingController _eventEndDateTimeController =
      TextEditingController();

  final List<String> _repeatTypes = EventRepeatType.values
      .map((e) => e.name.capitalizeFirst)
      .toList();
  String? _selectedRepeatType;

  DateTime? _selectedEventDateTime;
  DateTime? _selectedEndEventDateTime;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _vScrollController = ScrollController();
  late Future _future;
  late EventModel _eventModel;
  bool _completed = false;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {
      _eventModel = await EventService.getEvent(uid: widget.uid);

      _eventNameController.text = _eventModel.eventName;
      _eventDescriptionController.text = _eventModel.eventDescription;
      _eventDateTimeController.text =
          _eventModel.eventDateTime.formatDateTime24Hrs;
      _eventEndDateTimeController.text =
          _eventModel.eventEndDateTime.formatDateTime24Hrs;
      _selectedEventDateTime = _eventModel.eventDateTime;
      _selectedEndEventDateTime = _eventModel.eventEndDateTime;

      _selectedRepeatType = _eventModel.eventRepeatType.name.capitalizeFirst;
      _completed = _eventModel.completed;

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (!mounted) return;
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDescriptionController.dispose();
    _eventDateTimeController.dispose();
    _eventEndDateTimeController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit Event",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this event's details and schedule",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final Color badgeColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: badgeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const WaitingLoading();
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _vScrollController,
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: _buildSectionCard(
                            icon: Iconsax.calendar_1,
                            title: "Event Details",
                            subtitle: "Update this event's schedule and status",
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  _buildFormFields(constraints, 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: "Update",
          icon: Iconsax.edit,
          onSubmit: _submitForm,
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Event Name',
            controller: _eventNameController,
            hintText: 'Enter Event Name',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.calendar_1, size: 18),
            valid: (input) => input == null || input.isEmpty
                ? 'Event Name is required'
                : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Event Description',
            controller: _eventDescriptionController,
            hintText: 'Enter Event Description',
            maxLines: 2,
            prefixIcon: const Icon(Iconsax.document_text, size: 18),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            controller: _eventDateTimeController,
            readOnly: true,
            onTap: () async {
              var date = await datePicker(context);
              if (date != null) {
                if (!mounted) return;
                var time = await pickTime(context, null);
                if (time != null) {
                  _eventDateTimeController.text =
                      '${date.formatDate} ${time.hour}:${time.minute}:00';
                  _selectedEventDateTime = date.copyWith(
                    hour: time.hour,
                    minute: time.minute,
                  );
                  setState(() {});
                }
              }
            },
            hintText: 'DD/MM/YYYY HH:MM:SS',
            suffixIcon: const Icon(Iconsax.calendar_1),
            label: 'Event Date & Time',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            controller: _eventEndDateTimeController,
            readOnly: true,
            onTap: () async {
              var date = await datePicker(context);
              if (date != null) {
                if (!mounted) return;
                var time = await pickTime(context, null);
                if (time != null) {
                  _eventEndDateTimeController.text =
                      '${date.formatDate} ${time.hour}:${time.minute}:00';
                  _selectedEndEventDateTime = date.copyWith(
                    hour: time.hour,
                    minute: time.minute,
                  );
                  setState(() {});
                }
              }
            },
            hintText: 'DD/MM/YYYY HH:MM:SS',
            suffixIcon: const Icon(Iconsax.calendar_1),
            label: 'Event End Date & Time',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Repeat',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomSearchableDropdown(
                initialValue: _selectedRepeatType,
                items: _repeatTypes.map((e) => e).toList(),
                onChanged: (value) {
                  final rp = _repeatTypes.firstWhere(
                    (element) => element == value,
                  );
                  _selectedRepeatType = rp;
                },
                itemAsString: (s) => s,
              ),
            ],
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              ModernCheckbox(
                value: _completed,
                label: 'Is Completed',
                onChanged: (val) {
                  _completed = val;
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        EventModel eventModel = EventModel(
          eventName: _eventNameController.text.trim(),
          eventDateTime: _selectedEventDateTime ?? DateTime.now(),
          eventEndDateTime:
              _selectedEndEventDateTime ??
              DateTime.now().add(const Duration(hours: 1)),
          eventDescription: _eventDescriptionController.text.trim(),
          eventRepeatType: EventRepeatType.values.firstWhere(
            (e) =>
                e.name.capitalizeFirst ==
                (_selectedRepeatType ??
                    EventRepeatType.none.name.capitalizeFirst),
          ),
          eventAttendes: [],
          completed: _completed,
          createdBy: await Spdb.getUser(),
        );

        await EventService.editEvent(
          uid: _eventModel.uid ?? '',
          event: eventModel,
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Event updated successfully', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        debugPrint("${e.toString()}, ${st.toString()}");
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}