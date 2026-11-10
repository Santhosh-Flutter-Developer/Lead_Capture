/// Minimal stand-in for the old Firestore `Timestamp`. The PHP API never
/// returns it; it only survives so model `fromMap` code written for cached /
/// legacy maps keeps compiling. Dates now travel as epoch millis or strings.
class Timestamp {
  final DateTime _date;
  const Timestamp._(this._date);
  factory Timestamp.fromDate(DateTime d) => Timestamp._(d);
  DateTime toDate() => _date;
}

/// Reads epoch millis / ISO-or-MySQL string / DateTime / Timestamp.
DateTime anyToDate(dynamic v, [DateTime? fallback]) {
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) {
    final d = DateTime.tryParse(v.replaceFirst(' ', 'T'));
    if (d != null) return d;
  }
  return fallback ?? DateTime.now();
}
