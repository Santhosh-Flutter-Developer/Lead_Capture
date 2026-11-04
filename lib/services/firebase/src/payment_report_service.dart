import '/models/models.dart';
import '/services/services.dart';

/// Raw data the Payment Report is calculated from.
class PaymentReportSource {
  final List<ClientModel> clients;
  final List<DealModel> deals; // completed deals only
  final List<ProjectUpdationModel> updations;
  final List<PaymentModel> payments;

  const PaymentReportSource({
    required this.clients,
    required this.deals,
    required this.updations,
    required this.payments,
  });
}

/// Loads and calculates the Payment Report. Calculation is a pure function
/// ([build]) so it does not depend on Firestore.
class PaymentReportService {
  /// Fetches everything the report needs in parallel.
  static Future<PaymentReportSource> load() async {
    final r = await Future.wait([
      ClientService.getMasterClients(),
      DealService.getAllDeals(),
      ProjectUpdationService.getAllUpdations(),
      PaymentService.getAll(),
    ]);
    // Every deal (a lead converted to a deal) and every project updation is
    // reported from the moment it is created - a payment is not needed.
    return PaymentReportSource(
      clients: r[0] as List<ClientModel>,
      deals: r[1] as List<DealModel>,
      updations: r[2] as List<ProjectUpdationModel>,
      payments: r[3] as List<PaymentModel>,
    );
  }

  static String clientLabel(ClientModel c) {
    final contact = (c.clientName ?? '').trim();
    return contact.isEmpty ? c.displayName : '${c.displayName} - $contact';
  }

  static String _dealName(DealModel d) =>
      (d.projectName ?? '').trim().isEmpty ? d.dealName : d.projectName!.trim();

  static bool _inRange(DateTime d, DateTime? from, DateTime? to) =>
      (from == null || !d.isBefore(from)) && (to == null || !d.isAfter(to));

  /// One row per Master Client that has deals or project updations.
  ///
  /// * Projects are all deals (converted leads), whatever their status, and
  ///   project updations are all updations raised against them. They show
  ///   as Pending as soon as they exist, before any payment is made. A
  ///   payment whose deal was deleted is still reported from its snapshot.
  /// * [from]/[to] limit which deals (by created date) and updations (by
  ///   requested date) are reported. Payments allocated to them are always
  ///   counted in full, so Pending/Completed stays truthful.
  /// * Payment lines without an updation count as payment allocated; lines
  ///   with an updation count as project update allocated.
  static List<PaymentReportRow> build(
    PaymentReportSource src, {
    DateTime? from,
    DateTime? to,
  }) {
    final clientById = {
      for (final c in src.clients)
        if (c.uid != null) c.uid!: c,
    };

    // Received per deal (no updation) and per updation.
    final dealReceived = <String, double>{};
    final updationReceived = <String, double>{};
    for (final p in src.payments) {
      final updId = p.updationId ?? '';
      if (updId.isEmpty) {
        dealReceived[p.projectId] =
            (dealReceived[p.projectId] ?? 0) + p.allocatedValue;
      } else {
        updationReceived[updId] =
            (updationReceived[updId] ?? 0) + p.allocatedValue;
      }
    }

    final dealById = {
      for (final d in src.deals)
        if (d.uid != null) d.uid!: d,
    };

    final dealsByClient = <String, List<PaymentReportDeal>>{};
    final updsByClient = <String, List<PaymentReportUpdation>>{};
    final names = <String, String>{};

    String keyOf(String? clientId, String fallbackName) {
      final id = clientId ?? '';
      if (id.isNotEmpty) {
        final c = clientById[id];
        names[id] = c != null ? clientLabel(c) : fallbackName;
        return id;
      }
      final key = 'name:${fallbackName.toLowerCase()}';
      names[key] = fallbackName;
      return key;
    }

    String keyFor(DealModel d) => keyOf(
      d.clientId,
      (d.companyName ?? d.clientName ?? d.dealName).trim(),
    );

    for (final d in src.deals) {
      if (d.uid == null || !_inRange(d.createdAt, from, to)) continue;
      dealsByClient
          .putIfAbsent(keyFor(d), () => [])
          .add(
            PaymentReportDeal(
              dealId: d.uid!,
              name: _dealName(d),
              dealNumber: d.dealNumber,
              value: d.dealValue,
              received: dealReceived[d.uid!] ?? 0,
            ),
          );
    }

    // Payments whose deal record no longer exists: report them from the
    // snapshot saved on the payment so the money is never dropped.
    final orphanLines = <String, List<PaymentModel>>{};
    for (final p in src.payments) {
      if ((p.updationId ?? '').isEmpty && !dealById.containsKey(p.projectId)) {
        orphanLines.putIfAbsent(p.projectId, () => []).add(p);
      }
    }
    for (final e in orphanLines.entries) {
      final lines = e.value;
      final first = lines.first;
      final at = lines.map((l) => l.createdAt).reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      if (!_inRange(at, from, to)) continue;
      dealsByClient
          .putIfAbsent(
            keyOf(first.clientId, first.clientLabel.trim().isEmpty
                ? 'Unknown client'
                : first.clientLabel.trim()),
            () => [],
          )
          .add(
            PaymentReportDeal(
              dealId: e.key,
              name: first.projectName.trim().isEmpty
                  ? 'Deleted project'
                  : first.projectName.trim(),
              dealNumber: null,
              value: first.dealValue,
              received: lines.fold(0.0, (s, l) => s + l.allocatedValue),
            ),
          );
    }

    for (final u in src.updations) {
      final deal = dealById[u.projectId];
      final value = u.value ?? 0;
      if (u.uid == null || !_inRange(u.requestedDate, from, to)) continue;
      // Updations of a deleted deal are only reported when money was
      // already allocated to them.
      if (deal == null && !updationReceived.containsKey(u.uid)) continue;
      final key = deal != null
          ? keyFor(deal)
          : keyOf(
              u.clientId,
              (u.companyName ?? u.contactName ?? u.projectName).trim(),
            );
      updsByClient
          .putIfAbsent(key, () => [])
          .add(
            PaymentReportUpdation(
              updationId: u.uid!,
              code: u.updationCode,
              title: u.title,
              projectName: deal != null ? _dealName(deal) : u.projectName,
              value: value,
              received: updationReceived[u.uid!] ?? 0,
            ),
          );
    }

    final keys = {...dealsByClient.keys, ...updsByClient.keys};
    final rows = [
      for (final k in keys)
        PaymentReportRow(
          clientId: k.startsWith('name:') ? '' : k,
          clientName: names[k] ?? '-',
          deals: dealsByClient[k] ?? const [],
          updations: updsByClient[k] ?? const [],
        ),
    ]..sort((a, b) => a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()));
    return rows;
  }
}