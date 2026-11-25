import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';

const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Preset accent colours (blue, sky, green, purple, amber, red).
const List<int> _presetAccents = [
  0xFF4364F7,
  0xFF0EA5E9,
  0xFF10B981,
  0xFF8B5CF6,
  0xFFF59E0B,
  0xFFEF4444,
];

/// Shared "Add Event" / "Edit Event" panel.
///
/// * [initial] == null  -> create mode ([selectedDate] pre-fills the date)
/// * [initial] != null  -> edit mode
class EventFormPanel extends StatefulWidget {
  final EventModel? initial;
  final DateTime? selectedDate;
  const EventFormPanel({super.key, this.initial, this.selectedDate});

  @override
  State<EventFormPanel> createState() => _EventFormPanelState();
}

class _EventFormPanelState extends State<EventFormPanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _vScrollController = ScrollController();

  late DateTime _start;
  late DateTime _end;
  EventType _eventType = EventType.meeting;
  EventRepeatType _repeatType = EventRepeatType.none;
  int _accent = EventModel.defaultAccent;
  bool _allDay = false;
  bool _completed = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    if (e != null) {
      _titleController.text = e.eventName;
      _descriptionController.text = e.eventDescription;
      _start = e.eventDateTime;
      _end = e.eventEndDateTime;
      _eventType = e.eventType;
      _repeatType = e.eventRepeatType;
      _accent = e.accentColor;
      _allDay = e.allDay;
      _completed = e.completed;
    } else {
      final d = widget.selectedDate ?? DateTime.now();
      _start = DateTime(d.year, d.month, d.day, 9);
      _end = DateTime(d.year, d.month, d.day, 10);
    }
    _syncTexts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startController.dispose();
    _endController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  String _fmt(DateTime d) => _allDay ? d.formatDate : d.formatDateTime;

  void _syncTexts() {
    _startController.text = _fmt(_start);
    _endController.text = _fmt(_end);
  }

  Future<DateTime?> _pickDateTime(DateTime current) async {
    final date = await datePicker(context);
    if (date == null || !mounted) return null;
    if (_allDay) return DateTime(date.year, date.month, date.day);
    final time = await pickTime(
      context,
      TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_start);
    if (picked == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = picked;
      // Keep the event length; if the old range was invalid use 1 hour.
      _end = _start.add(
        duration.isNegative || duration == Duration.zero
            ? const Duration(hours: 1)
            : duration,
      );
      if (_allDay) _end = DateTime(_end.year, _end.month, _end.day, 23, 59);
      _syncTexts();
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_end);
    if (picked == null) return;
    setState(() {
      _end = _allDay
          ? DateTime(picked.year, picked.month, picked.day, 23, 59)
          : picked;
      _syncTexts();
    });
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _allDay = value;
      if (value) {
        _start = DateTime(_start.year, _start.month, _start.day);
        _end = DateTime(_end.year, _end.month, _end.day, 23, 59);
      } else {
        _start = DateTime(_start.year, _start.month, _start.day, 9);
        _end = DateTime(_start.year, _start.month, _start.day, 10);
      }
      _syncTexts();
    });
  }

  Future<void> _pickCustomColor() async {
    Color temp = Color(_accent);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a colour'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            enableAlpha: false,
            hexInputBar: true,
            onColorChanged: (c) => temp = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, temp),
            child: const Text('Select'),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() => _accent = picked.toARGB32() | 0xFF000000);
    }
  }

  // ---------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      FlushBar.show(
        context,
        'End date & time must be after the start',
        isSuccess: false,
      );
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final navigator = Navigator.of(context);
    futureLoading(context);
    try {
      final model = EventModel(
        eventName: _titleController.text.trim(),
        eventDateTime: _start,
        eventEndDateTime: _end,
        eventDescription: _descriptionController.text.trim(),
        eventRepeatType: _repeatType,
        eventAttendes: widget.initial?.eventAttendes ?? [],
        completed: _completed,
        eventType: _eventType,
        accentColor: _accent,
        allDay: _allDay,
        createdBy: await Spdb.getUser(),
      );

      if (_isEdit) {
        await EventService.editEvent(
          uid: widget.initial!.uid ?? '',
          event: model,
        );
      } else {
        await EventService.createEvent(event: model);
      }

      rootNavigator.pop(); // loading
      if (navigator.canPop()) navigator.pop(true); // sheet
      if (!mounted) return;
      FlushBar.show(
        context,
        _isEdit ? 'Event updated successfully' : 'Event created successfully',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      rootNavigator.pop(); // loading
      if (!mounted) return;
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

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
            _buildHeader(),
            Expanded(
              child: Scrollbar(
                controller: _vScrollController,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(8),
                thickness: 6,
                child: SingleChildScrollView(
                  controller: _vScrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Form(key: _formKey, child: _buildFields()),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEdit ? Iconsax.edit : Iconsax.calendar_1,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Event' : 'Add Event',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? "Update this event's details and schedule"
                      : 'Schedule meetings, reminders and calendar appointments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            icon: const Icon(Icons.close, color: AppColors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _twoColumns(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 380) {
          return Column(children: [a, const SizedBox(height: 4), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required List<T> items,
    required T value,
    required String Function(T) asString,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        CustomSearchableDropdown<T>(
          items: items,
          initialValue: value,
          itemAsString: asString,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildFields() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFields(
          label: 'Event Title',
          controller: _titleController,
          hintText: 'e.g. Client Strategy Call',
          isRequired: true,
          valid: (v) =>
              v == null || v.trim().isEmpty ? 'Event title is required' : null,
        ),
        const SizedBox(height: 8),
        FormFields(
          label: 'Description',
          controller: _descriptionController,
          hintText: 'Notes, agenda or meeting location...',
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        _twoColumns(
          FormFields(
            label: 'Start Date & Time',
            controller: _startController,
            readOnly: true,
            isRequired: true,
            onTap: _pickStart,
            hintText: 'DD-MM-YYYY HH:MM',
            suffixIcon: const Icon(Iconsax.calendar_1, size: 18),
          ),
          FormFields(
            label: 'End Date & Time',
            controller: _endController,
            readOnly: true,
            onTap: _pickEnd,
            hintText: 'DD-MM-YYYY HH:MM',
            suffixIcon: const Icon(Iconsax.calendar_1, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        _twoColumns(
          _dropdownField<EventType>(
            label: 'Event Type',
            items: EventType.values,
            value: _eventType,
            asString: (t) => t.label,
            onChanged: (t) => _eventType = t,
          ),
          _dropdownField<EventRepeatType>(
            label: 'Repeat Schedule',
            items: EventRepeatType.values,
            value: _repeatType,
            asString: (t) => t.scheduleLabel,
            onChanged: (t) => _repeatType = t,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Accent Color',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickCustomColor,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(_accent),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            for (final c in _presetAccents)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _accent = c),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: _accent == c
                          ? Border.all(color: cs.onSurface, width: 2)
                          : null,
                    ),
                    child: _accent == c
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(value: _allDay, onChanged: _toggleAllDay),
            ),
            const SizedBox(width: 4),
            Text(
              'All Day Event',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (_isEdit) ...[
          const SizedBox(height: 6),
          ModernCheckbox(
            value: _completed,
            label: 'Is Completed',
            onChanged: (v) => setState(() => _completed = v),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: _brandGradient),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: Text(
                    _isEdit ? 'Update Event' : 'Save Event',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
}