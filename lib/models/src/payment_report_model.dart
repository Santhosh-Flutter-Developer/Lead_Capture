/// Payment status of a client (or of a single deal / updation) in the
/// Payment Report. It is `completed` only when everything billed has been
/// received; any shortfall keeps it `pending`.
enum PaymentReportStatus { pending, completed }

extension PaymentReportStatusX on PaymentReportStatus {
  String get label => this == PaymentReportStatus.completed
      ? 'Completed'
      : 'Pending';

  /// Nothing billed yet (total 0) is still Pending. Money values are compared with a small tolerance so floating point
  /// noise (e.g. 0.1 + 0.2) never leaves a fully paid item "Pending".
  static PaymentReportStatus of({
    required double total,
    required double received,
  }) => total > 0 && (total - received).abs() < 0.01
      ? PaymentReportStatus.completed
      : PaymentReportStatus.pending;
}

/// One project (completed deal) inside a client's report row.
class PaymentReportDeal {
  final String dealId;
  final String name;
  final int? dealNumber;
  final double value;
  final double received;

  const PaymentReportDeal({
    required this.dealId,
    required this.name,
    required this.dealNumber,
    required this.value,
    required this.received,
  });

  double get balance => value - received;
  PaymentReportStatus get status =>
      PaymentReportStatusX.of(total: value, received: received);
}

/// One project updation inside a client's report row.
class PaymentReportUpdation {
  final String updationId;
  final String code;
  final String title;
  final String projectName;
  final double value;
  final double received;

  const PaymentReportUpdation({
    required this.updationId,
    required this.code,
    required this.title,
    required this.projectName,
    required this.value,
    required this.received,
  });

  double get balance => value - received;
  PaymentReportStatus get status =>
      PaymentReportStatusX.of(total: value, received: received);
}

/// One row of the Payment Report: a Master Client with its deals, project
/// updations and payment totals.
///
/// * Deal Value     = total project (deal) value + total project updation value
/// * Received Value = total payment allocated + total updation allocated
/// * Status         = Completed only when Received == Deal Value, else Pending
class PaymentReportRow {
  final String clientId;
  final String clientName;
  final List<PaymentReportDeal> deals;
  final List<PaymentReportUpdation> updations;

  const PaymentReportRow({
    required this.clientId,
    required this.clientName,
    required this.deals,
    required this.updations,
  });

  double get projectValue => deals.fold(0.0, (s, d) => s + d.value);
  double get updationValue => updations.fold(0.0, (s, u) => s + u.value);

  /// Total project value + total project update value.
  double get dealValue => projectValue + updationValue;

  double get paymentAllocated => deals.fold(0.0, (s, d) => s + d.received);
  double get updationAllocated =>
      updations.fold(0.0, (s, u) => s + u.received);

  /// Total payment allocated + total project update allocated.
  double get receivedValue => paymentAllocated + updationAllocated;

  double get balance => dealValue - receivedValue;

  /// 0.0 – 1.0 share of the deal value that has been received.
  double get progress =>
      dealValue <= 0 ? 0 : (receivedValue / dealValue).clamp(0.0, 1.0);

  PaymentReportStatus get status =>
      PaymentReportStatusX.of(total: dealValue, received: receivedValue);

  bool get isCompleted => status == PaymentReportStatus.completed;

  String get dealNames => deals.map((d) => d.name).join(', ');
  String get updationNames => updations
      .map((u) => u.title.isEmpty ? u.code : '${u.code} ${u.title}')
      .join(', ');
}

/// Totals shown in the summary cards above the table.
class PaymentReportSummary {
  final int clients;
  final int pendingClients;
  final int completedClients;
  final double dealValue;
  final double receivedValue;

  const PaymentReportSummary({
    required this.clients,
    required this.pendingClients,
    required this.completedClients,
    required this.dealValue,
    required this.receivedValue,
  });

  factory PaymentReportSummary.of(List<PaymentReportRow> rows) {
    final completed = rows.where((r) => r.isCompleted).length;
    return PaymentReportSummary(
      clients: rows.length,
      completedClients: completed,
      pendingClients: rows.length - completed,
      dealValue: rows.fold(0.0, (s, r) => s + r.dealValue),
      receivedValue: rows.fold(0.0, (s, r) => s + r.receivedValue),
    );
  }

  double get balance => dealValue - receivedValue;
  double get progress =>
      dealValue <= 0 ? 0 : (receivedValue / dealValue).clamp(0.0, 1.0);
}

/// Date presets offered by the report's date filter.
enum PaymentReportPeriod {
  allTime,
  today,
  yesterday,
  thisWeek,
  lastWeek,
  lastMonth,
  thisMonth,
  lastYear,
  thisYear,
  custom,
}

extension PaymentReportPeriodX on PaymentReportPeriod {
  String get label {
    switch (this) {
      case PaymentReportPeriod.allTime:
        return 'All Time';
      case PaymentReportPeriod.today:
        return 'Today';
      case PaymentReportPeriod.yesterday:
        return 'Yesterday';
      case PaymentReportPeriod.thisWeek:
        return 'This Week';
      case PaymentReportPeriod.lastWeek:
        return 'Last Week';
      case PaymentReportPeriod.lastMonth:
        return 'Last Month';
      case PaymentReportPeriod.thisMonth:
        return 'This Month';
      case PaymentReportPeriod.lastYear:
        return 'Last Year';
      case PaymentReportPeriod.thisYear:
        return 'This Year';
      case PaymentReportPeriod.custom:
        return 'Custom Date';
    }
  }

  /// Inclusive [from, to] range of the preset, or null for All Time /
  /// Custom (custom ranges come from the date-range picker). Weeks run
  /// Monday to Sunday.
  ({DateTime from, DateTime to})? range([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    DateTime endOf(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    switch (this) {
      case PaymentReportPeriod.allTime:
      case PaymentReportPeriod.custom:
        return null;
      case PaymentReportPeriod.today:
        return (from: today, to: endOf(today));
      case PaymentReportPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: endOf(y));
      case PaymentReportPeriod.thisWeek:
        return (from: weekStart, to: endOf(weekStart.add(const Duration(days: 6))));
      case PaymentReportPeriod.lastWeek:
        final s = weekStart.subtract(const Duration(days: 7));
        return (from: s, to: endOf(s.add(const Duration(days: 6))));
      case PaymentReportPeriod.thisMonth:
        return (
          from: DateTime(n.year, n.month, 1),
          to: endOf(DateTime(n.year, n.month + 1, 0)),
        );
      case PaymentReportPeriod.lastMonth:
        return (
          from: DateTime(n.year, n.month - 1, 1),
          to: endOf(DateTime(n.year, n.month, 0)),
        );
      case PaymentReportPeriod.thisYear:
        return (from: DateTime(n.year, 1, 1), to: endOf(DateTime(n.year, 12, 31)));
      case PaymentReportPeriod.lastYear:
        return (
          from: DateTime(n.year - 1, 1, 1),
          to: endOf(DateTime(n.year - 1, 12, 31)),
        );
    }
  }
}