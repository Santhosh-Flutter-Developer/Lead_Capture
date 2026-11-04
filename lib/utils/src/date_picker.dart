import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<DateTime?> datePicker(context,
    {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate}) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(1980, 01, 01),
    lastDate: lastDate ?? DateTime(2100, 12, 31),
  );
  return picked;
}

Future<String?> pickDate(context,
    {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate}) async {
  final DateTime? picked = await datePicker(
    context,
    initialDate: initialDate ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day,
            00, 00, 00),
    firstDate: firstDate ?? DateTime(1980, 01, 01),
    lastDate: lastDate ?? DateTime(2100, 12, 31),
  );
  if (picked != null) {
    return DateFormat('dd-MM-yyyy').format(picked);
  }
  return null;
}

Future<TimeOfDay?> pickTime(context, TimeOfDay? selectedTime) async {
  final TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: selectedTime ?? TimeOfDay.now(),
  );

  if (pickedTime != null && pickedTime != selectedTime) {
    return pickedTime;
  }
  return null;
}

TimeOfDay parseTimeOfDay(String timeString) {
  // Use DateFormat to parse the string into a DateTime object
  final format = RegExp(r"(\d+):(\d+)\s*(AM|PM)");
  final match = format.firstMatch(timeString);

  if (match != null) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    // Convert 12-hour time to 24-hour time
    final convertedHour = period == "PM" && hour != 12
        ? hour + 12
        : period == "AM" && hour == 12
            ? 0
            : hour;

    return TimeOfDay(hour: convertedHour, minute: minute);
  }

  throw FormatException("Invalid time format: $timeString");
}

String formatTimeOfDay(TimeOfDay time) {
  var hourInt = time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  if (time.period == DayPeriod.pm) {
    hourInt = hourInt + 12;
  }
  var hour = hourInt.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Duration getDuration(TimeOfDay time1, TimeOfDay time2) {
  // Helper function to convert TimeOfDay to total minutes since midnight
  int toMinutesSinceMidnight(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // Convert both times to minutes since midnight
  int minutes1 = toMinutesSinceMidnight(time1);
  int minutes2 = toMinutesSinceMidnight(time2);

  // Calculate the difference
  int diff = minutes2 - minutes1;

  // If the difference is negative (time2 is on the next day), add 24 hours in minutes
  if (diff < 0) {
    diff += 24 * 60;
  }

  // Return the difference as a Duration
  return Duration(minutes: diff);
}

Duration getDurationDates(DateTime date1, DateTime date2) {
  return date2.difference(date1);
}

String getOverallTime(
    DateTime start, DateTime end, Map<String, dynamic> breaks) {
  Duration totalDuration = end.difference(start);

  if (breaks.isNotEmpty) {
    String breakDuration = calculateBreaks(breaks);
    List<String> breakParts = breakDuration.split(':');
    Duration breakDurationParsed = Duration(
      hours: int.parse(breakParts[0]),
      minutes: int.parse(breakParts[1]),
    );

    totalDuration -= breakDurationParsed;
  }

  return "${totalDuration.inHours.toString().padLeft(2, '0')}:${totalDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${totalDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
}

String durationToTime(Duration duration) {
  return "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
}

Duration getOverallTimeDuration(
    DateTime start, DateTime end, Map<String, dynamic> breaks) {
  Duration totalDuration = end.difference(start);

  if (breaks.isNotEmpty) {
    String breakDuration = calculateBreaks(breaks);
    List<String> breakParts = breakDuration.split(':');
    Duration breakDurationParsed = Duration(
      hours: int.parse(breakParts[0]),
      minutes: int.parse(breakParts[1]),
    );

    totalDuration -= breakDurationParsed;
  }

  return totalDuration;
}

String calculateBreaks(Map<String, dynamic> breaks) {
  Duration totalBreakDuration = Duration.zero;

  for (var entry in breaks.entries) {
    var breakData = entry.value;

    if (breakData["end"] != null) {
      if (breakData["start"] is int && breakData["end"] is int) {
        final start = DateTime.fromMillisecondsSinceEpoch(entry.value["start"]);
        final end = entry.value["end"] != null
            ? DateTime.fromMillisecondsSinceEpoch(entry.value["end"])
            : null;

        if (end != null) {
          totalBreakDuration += end.difference(start);
        }
      }
    }
  }

  return "${totalBreakDuration.inHours.toString().padLeft(2, '0')}:${totalBreakDuration.inMinutes.toString().padLeft(2, '0')}";
}

Future<DateTimeRange?> dateRangePicker(
    context, DateTimeRange? selectedDateRange) async {
  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
    initialDateRange: selectedDateRange,
    builder: (context, child) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 100),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
      );
    },
  );

  return picked;
}
