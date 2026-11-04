import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

class HolidayForm extends StatefulWidget {
  final HolidayModel? holiday;
  const HolidayForm({super.key, this.holiday});

  @override
  State<HolidayForm> createState() => _HolidayFormState();
}

class _HolidayFormState extends State<HolidayForm> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _reasonController = TextEditingController();
  final _daysController = TextEditingController(text: '1');

  bool _isLoading = false;
  bool _isCheckingDate = false;
  String? _dateAvailabilityMessage;

  bool get isEdit => widget.holiday != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(widget.holiday!.date);
      _reasonController.text = widget.holiday!.reason;
      _daysController.text = widget.holiday!.days.toString();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _checkDateAvailability(DateTime date) async {
    setState(() {
      _isCheckingDate = true;
      _dateAvailabilityMessage = null;
    });

    try {
      final isTaken = await HolidayService.isDateTaken(
        date,
        excludeId: widget.holiday?.uid,
      );

      if (!mounted) return;

      setState(() {
        _dateAvailabilityMessage = isTaken
            ? 'A holiday already exists on this date'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dateAvailabilityMessage = 'Error checking date';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDate = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateAvailabilityMessage != null) return;

    setState(() => _isLoading = true);

    try {
      final user = await Spdb.getUser();
      final date = DateFormat('yyyy-MM-dd').parse(_dateController.text.trim());

      if (isEdit) {
        final holiday = HolidayModel(
          uid: widget.holiday!.uid,
          date: date,
          reason: _reasonController.text.trim(),
          days: int.tryParse(_daysController.text.trim()) ?? 1,
          createdBy: widget.holiday!.createdBy,
          createdAt: widget.holiday!.createdAt,
          updatedAt: DateTime.now(),
        );

        await HolidayService.updateHoliday(
          uid: widget.holiday!.uid!,
          holiday: holiday,
        );

        if (!mounted) return;
        FlushBar.show(context, 'Holiday updated successfully');
      } else {
        final holiday = HolidayModel(
          date: date,
          reason: _reasonController.text.trim(),
          days: int.tryParse(_daysController.text.trim()) ?? 1,
          createdBy: user,
        );

        await HolidayService.createHoliday(holiday: holiday);

        if (!mounted) return;
        FlushBar.show(context, 'Holiday added successfully');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, 'Failed to save holiday: $e', isSuccess: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FormWidgets.buildHeader(
        context: context,
        title: isEdit ? "Edit Holiday" : "Add Holiday",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormFields(
                controller: _dateController,
                label: "Date",
                isRequired: true,
                readOnly: true,
                valid: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Date is required';
                  }
                  return null;
                },
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    final formatted = DateFormat('yyyy-MM-dd').format(picked);
                    setState(() => _dateController.text = formatted);
                    _checkDateAvailability(picked);
                  }
                },
              ),
              if (_dateAvailabilityMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dateAvailabilityMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FormFields(
                controller: _reasonController,
                label: "Reason",
                isRequired: true,
                valid: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Reason must be at least 2 characters';
                  }
                  if (value.trim().length > 100) {
                    return 'Reason must not exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormFields(
                controller: _daysController,
                label: "No. of Days",
                isRequired: true,
                keyboardType: TextInputType.number,
                valid: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'No. of Days is required';
                  }
                  final d = int.tryParse(value.trim());
                  if (d == null) {
                    return 'Must be a whole number';
                  }
                  if (d < 1) {
                    return 'Days must be at least 1';
                  }
                  if (d > 30) {
                    return 'Days cannot exceed 30';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? "Update" : "Add"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
