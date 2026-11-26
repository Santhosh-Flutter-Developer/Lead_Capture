import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/constants/src/enum.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

const Color _blue = Color(0xFF2563EB);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE2E8F0);

/// "Lead Follow-up Performance & Status Graph" (reference: Graph / Status
/// Graph button). Staff multi-select + date range + quick presets, four
/// summary cards, a status-wise bar chart and a status share donut.
class LeadStatusGraph extends StatefulWidget {
  final List<LeadModel> leads;
  final List<LeadStatusModel> statuses;

  /// Called with the follow-up employee uid ('' = unassigned) when
  /// "View Leads" is tapped in the leaderboard.
  final void Function(String? employeeUid)? onViewLeads;
  const LeadStatusGraph({
    super.key,
    required this.leads,
    required this.statuses,
    this.onViewLeads,
  });

  @override
  State<LeadStatusGraph> createState() => _LeadStatusGraphState();
}

class _LeadStatusGraphState extends State<LeadStatusGraph> {
  // Applied filters
  List<String> _staff = []; // employee uids; empty = all staff
  DateTime? _from;
  DateTime? _to;
  // Draft filters (changed in the form, committed with "Apply Filters")
  List<String> _draftStaff = [];
  DateTime? _draftFrom;
  DateTime? _draftTo;
  String _preset = 'All';
  bool _horizontal = false;
  int _resetCount = 0;
  final ScrollController _lbScroll = ScrollController();

  @override
  void dispose() {
    _lbScroll.dispose();
    super.dispose();
  }

  List<EmployeeModel> get _employees {
    try {
      return CacheService().getAllListenableEmployees().value;
    } catch (_) {
      return <EmployeeModel>[];
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'dd-mm-yyyy'
      : '${d.day.toString().padLeft(2, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-${d.year}';

  void _applyPreset(String p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = p;
      switch (p) {
        case 'Today':
          _draftFrom = today;
          _draftTo = today;
          break;
        case 'This Week':
          _draftFrom = today.subtract(Duration(days: today.weekday % 7));
          _draftTo = today;
          break;
        case 'This Month':
          _draftFrom = DateTime(today.year, today.month, 1);
          _draftTo = today;
          break;
        case 'Last 30D':
          _draftFrom = today.subtract(const Duration(days: 30));
          _draftTo = today;
          break;
        default:
          _draftFrom = null;
          _draftTo = null;
      }
    });
  }

  void _apply() {
    setState(() {
      _staff = List<String>.from(_draftStaff);
      _from = _draftFrom;
      _to = _draftTo;
    });
  }

  void _reset() {
    setState(() {
      _staff = [];
      _draftStaff = [];
      _from = _to = _draftFrom = _draftTo = null;
      _preset = 'All';
      _resetCount++;
    });
  }

  List<LeadModel> get _scoped {
    return widget.leads.where((l) {
      if (_staff.isNotEmpty && !_staff.contains(l.followUp)) return false;
      if (_from != null && l.createdAt.isBefore(_from!)) return false;
      if (_to != null &&
          l.createdAt.isAfter(
            DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pick(bool from) async {
    final p = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: (from ? _draftFrom : _draftTo) ?? DateTime.now(),
    );
    if (p == null) return;
    setState(() {
      _preset = '';
      if (from) {
        _draftFrom = p;
      } else {
        _draftTo = p;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leads = _scoped;
    final statuses = [...widget.statuses]
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    final counts = <String, int>{
      for (final s in statuses) s.uid ?? s.name: 0,
    };
    for (final l in leads) {
      counts[l.leadStatus] = (counts[l.leadStatus] ?? 0) + 1;
    }
    final total = leads.length;
    final converted = leads.where((l) => l.leadsConverted).length;
    final inProgress = total - converted;
    final staffCount = leads
        .map((l) => l.followUp ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;
    final rate = total == 0 ? 0 : (converted * 100 / total).round();

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final cards = [
          _stat(
            'TOTAL ASSIGNED LEADS',
            '$total',
            _rangeText(),
            _blue,
            Iconsax.people,
            const Color(0xFFE2E8F0),
          ),
          _stat(
            'CONVERTED TO DEALS',
            '$converted',
            'Completed & moved to active pipeline',
            const Color(0xFF16A34A),
            Icons.check_circle,
            const Color(0xFF16A34A),
            badge: '$rate% Rate',
          ),
          _stat(
            'IN-PROGRESS LEADS',
            '$inProgress',
            'Currently undergoing follow-up',
            const Color(0xFFF59E0B),
            Icons.hourglass_bottom,
            const Color(0xFFF59E0B),
          ),
          _stat(
            'STAFF MEMBERS',
            '$staffCount',
            'Follow-up assignees evaluated',
            const Color(0xFF06B6D4),
            Iconsax.user,
            const Color(0xFF06B6D4),
          ),
        ];
        final barCard = _card(
          title: 'Status-wise Lead Count Distribution',
          subtitle: 'Number of leads in each stage for selected follow-up staff',
          trailing: _orientationToggle(),
          child: SizedBox(
            height: 300,
            child: _barChart(statuses, counts),
          ),
        );
        final pieCard = _card(
          title: 'Status Share Ratio',
          subtitle: 'Percentage breakdown',
          child: _donut(statuses, counts, total),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filterCard(),
            const SizedBox(height: 14),
            if (wide)
              Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final w in cards)
                    SizedBox(
                      width: c.maxWidth >= 560
                          ? (c.maxWidth - 12) / 2
                          : c.maxWidth,
                      child: w,
                    ),
                ],
              ),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: barCard),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: pieCard),
                ],
              )
            else ...[
              barCard,
              const SizedBox(height: 14),
              pieCard,
            ],
            const SizedBox(height: 14),
            _leaderboard(leads, statuses),
          ],
        );
      },
    );
  }


  // ---- Follow-up Staff Performance Leaderboard ------------------------
  static const List<double> _lw = [230, 100, 100, 260, 90, 170, 130, 120];

  Widget _lcell(int i, Widget child) => SizedBox(
    width: _lw[i],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );

  Widget _pillText(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  Widget _leaderboard(List<LeadModel> leads, List<LeadStatusModel> statuses) {
    final byStaff = <String, List<LeadModel>>{};
    for (final l in leads) {
      byStaff.putIfAbsent(l.followUp ?? '', () => []).add(l);
    }
    final rows = byStaff.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final totalW = _lw.fold(0.0, (a, b) => a + b);

    Widget head(int i, String t) => _lcell(
      i,
      Text(
        t,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _blue,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Iconsax.medal_star, color: const Color(0xFF7C3AED), size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up Staff Performance Leaderboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _ink,
                      ),
                    ),
                    Text(
                      'Individual staff lead distribution across statuses and conversion rates',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              _pillText(
                '${rows.length} Staff Members',
                const Color(0xFFF1F5F9),
                _muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Scrollbar(
            controller: _lbScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _lbScroll,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: totalW),
                child: SizedBox(
                  width: totalW,
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: _line)),
                        ),
                        child: Row(
                          children: [
                            head(0, 'Staff Member'),
                            head(1, 'Role'),
                            head(2, 'Total Leads'),
                            head(3, 'Status Breakdown'),
                            head(4, 'Converted'),
                            head(5, 'Conversion Rate'),
                            head(6, 'Pipeline Value'),
                            head(7, 'Action'),
                          ],
                        ),
                      ),
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No leads found',
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      for (final r in rows) _lbRow(r.key, r.value, statuses, money),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lbRow(
    String uid,
    List<LeadModel> list,
    List<LeadStatusModel> statuses,
    NumberFormat money,
  ) {
    final emp = uid.isEmpty ? null : CacheService.employeeByUid(uid);
    final name = uid.isEmpty ? 'Unassigned' : (emp?.name ?? 'Unknown');
    final email = emp?.email ?? '';
    // `designation` holds a designation uid: resolve it to the real name.
    final designationName = (emp == null || emp.designation.trim().isEmpty)
        ? ''
        : (CacheService.designationByUid(emp.designation)?.name ?? '');
    final role = uid.isEmpty
        ? 'Staff'
        : (designationName.isEmpty ? 'Employee' : designationName);
    final converted = list.where((l) => l.leadsConverted).length;
    final rate = list.isEmpty ? 0 : (converted * 100 / list.length).round();
    final pipeline = list.fold<double>(0, (a, l) => a + l.leadValue);
    final counts = <String, int>{};
    for (final l in list) {
      counts[l.leadStatus] = (counts[l.leadStatus] ?? 0) + 1;
    }

    return Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          _lcell(
            0,
            Row(
              children: [
                if (uid.isEmpty || emp == null)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  UserAvatar(
                    size: 28,
                    showCrown: false,
                    userData: UserDataModel(
                      uid: uid,
                      name: name,
                      profilePic: emp.profileImageUrl,
                      userType: UserType.employee,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        email.isEmpty ? '—' : email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _lcell(1, _pillText(role, const Color(0xFFF1F5F9), _muted)),
          _lcell(2, _pillText('${list.length}', _blue, Colors.white)),
          _lcell(
            3,
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final s in statuses)
                  if ((counts[s.uid ?? s.name] ?? 0) > 0)
                    _pillText(
                      '${s.name}: ${counts[s.uid ?? s.name]}',
                      Color(s.color).withValues(alpha: 0.14),
                      Color(s.color),
                    ),
              ],
            ),
          ),
          _lcell(
            4,
            Text(
              '$converted',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          _lcell(
            5,
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 6,
                      backgroundColor: _line,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$rate%', style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          _lcell(
            6,
            Text(
              money.format(pipeline),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          _lcell(
            7,
            OutlinedButton(
              onPressed: widget.onViewLeads == null
                  ? null
                  : () => widget.onViewLeads!(uid.isEmpty ? null : uid),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('View Leads', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  String _rangeText() {
    if (_from == null && _to == null) return 'All time record';
    return '${_fmt(_from)} - ${_fmt(_to)}';
  }

  BoxDecoration _box({Color? border, double width = 1}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border ?? _line, width: width),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _iconTile(IconData icon, {Color color = _blue, double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }

  Widget _filterCard() {
    final emps = _employees;
    final names = {for (final e in emps) e.uid ?? '': e.name};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Iconsax.chart_2),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Follow-up Performance & Status Graph',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Analyze status distribution by selecting one or multiple Follow-up staff members and custom date ranges',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _muted,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt, size: 16),
                label: const Text('Apply Filters'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up Staff Members   '
                      '${_draftStaff.isEmpty ? 'All Staff (${emps.length})' : '${_draftStaff.length} selected'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomSearchableDropdown<String>(
                      key: ValueKey('staff$_resetCount'),
                      items: names.keys.where((k) => k.isNotEmpty).toList(),
                      multiSelect: true,
                      showSelectAll: true,
                      initialValues: _draftStaff,
                      itemAsString: (u) => names[u] ?? u,
                      hintText: 'All Follow-up Staff (${emps.length})',
                      onChangedList: (v) => setState(() => _draftStaff = v),
                    ),
                  ],
                ),
              ),
              _dateBox('From Date', _draftFrom, () => _pick(true)),
              _dateBox('To Date', _draftTo, () => _pick(false)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Presets',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final p in const [
                        'All',
                        'Today',
                        'This Week',
                        'This Month',
                        'Last 30D',
                      ])
                        InkWell(
                          onTap: () => _applyPreset(p),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _preset == p ? _blue : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _preset == p ? _blue : _line,
                              ),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _preset == p ? Colors.white : _muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime? v, VoidCallback onTap) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fmt(v),
                      style: TextStyle(
                        fontSize: 12,
                        color: v == null ? _muted : _ink,
                      ),
                    ),
                  ),
                  const Icon(Iconsax.calendar_1, size: 15, color: _muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    String sub,
    Color valueColor,
    IconData icon,
    Color border, {
    String? badge,
  }) {
    final accent = border == const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(border: border, width: accent ? 1 : 1.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: accent ? _muted : valueColor,
                  ),
                ),
              ),
              _iconTile(icon, color: valueColor, size: 26),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: accent ? _ink : valueColor,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: valueColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Iconsax.chart_2, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _orientationToggle() {
    Widget seg(String t, bool on, VoidCallback f) => InkWell(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: on ? _blue : Colors.white,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: on ? Colors.white : _muted,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: _line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Vertical', !_horizontal, () => setState(() => _horizontal = false)),
            seg('Horizontal', _horizontal, () => setState(() => _horizontal = true)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(LeadStatusModel s) => Color(s.color);

  Widget _barChart(List<LeadStatusModel> statuses, Map<String, int> counts) {
    if (statuses.isEmpty) {
      return const Center(child: Text('No statuses'));
    }
    final maxV = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (_horizontal) {
      return ListView(
        children: [
          for (final s in statuses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      s.name,
                      style: const TextStyle(fontSize: 11, color: _muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bc) {
                        final v = counts[s.uid ?? s.name] ?? 0;
                        final w = maxV == 0 ? 0.0 : bc.maxWidth * v / maxV;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: w < 4 && v > 0 ? 4 : w,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _statusColor(s),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${counts[s.uid ?? s.name] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: _ink),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return BarChart(
      BarChartData(
        maxY: (maxV == 0 ? 1 : maxV + 1).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: _line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= statuses.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    statuses[i].name,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(enabled: true),
        barGroups: [
          for (int i = 0; i < statuses.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (counts[statuses[i].uid ?? statuses[i].name] ?? 0)
                      .toDouble(),
                  color: _statusColor(statuses[i]),
                  width: 26,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _donut(
    List<LeadStatusModel> statuses,
    Map<String, int> counts,
    int total,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: 62,
              sections: total == 0
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: _line,
                        radius: 34,
                        showTitle: false,
                      ),
                    ]
                  : [
                      for (final s in statuses)
                        if ((counts[s.uid ?? s.name] ?? 0) > 0)
                          PieChartSectionData(
                            value: (counts[s.uid ?? s.name] ?? 0).toDouble(),
                            color: _statusColor(s),
                            radius: 34,
                            showTitle: false,
                          ),
                    ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in statuses)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(fontSize: 11.5, color: _ink),
                  ),
                ),
                Text(
                  '${counts[s.uid ?? s.name] ?? 0}',
                  style: const TextStyle(fontSize: 11.5, color: _ink),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    total == 0
                        ? '0%'
                        : '${((counts[s.uid ?? s.name] ?? 0) * 100 / total).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}