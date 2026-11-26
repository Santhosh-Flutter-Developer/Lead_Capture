import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/services/services.dart';

enum _Preset { all, today, thisWeek, thisMonth, last30 }

/// "Deal Follow-up Performance & Status Graph" – data comes from deals.php
/// `status_graph` (filter by follow-up staff + created date range).
class DealsStatusGraph extends StatefulWidget {
  /// Called when "View Deals" is tapped on a leaderboard row.
  final ValueChanged<String>? onViewDeals;

  const DealsStatusGraph({super.key, this.onViewDeals});

  @override
  State<DealsStatusGraph> createState() => _DealsStatusGraphState();
}

class _DealsStatusGraphState extends State<DealsStatusGraph> {
  final Set<String> _staffIds = {};
  DateTime? _from;
  DateTime? _to;
  _Preset _preset = _Preset.all;
  bool _vertical = true;

  bool _loading = true;
  String? _error;
  List<_StatusRow> _statuses = [];
  List<_StaffRow> _staff = [];
  _Summary _summary = const _Summary();

  final DateFormat _dateFmt = DateFormat('dd-MM-yyyy');
  final DateFormat _labelFmt = DateFormat('dd MMM yyyy');
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ------------------------------------------------------------------ DATA

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DealService.getStatusGraph(
        staffIds: _staffIds.toList(),
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _statuses = Js.mapList(data['statuses']).map(_StatusRow.fromMap).toList();
        _staff = Js.mapList(data['staff_performance']).map(_StaffRow.fromMap).toList();
        _summary = _Summary.fromMap(Js.m(data['summary']));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _reset() {
    _staffIds.clear();
    _from = null;
    _to = null;
    _preset = _Preset.all;
    _load();
  }

  void _applyPreset(_Preset p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = p;
      switch (p) {
        case _Preset.all:
          _from = null;
          _to = null;
          break;
        case _Preset.today:
          _from = today;
          _to = today;
          break;
        case _Preset.thisWeek:
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to = today;
          break;
        case _Preset.thisMonth:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
          break;
        case _Preset.last30:
          _from = today.subtract(const Duration(days: 30));
          _to = today;
          break;
      }
    });
    _load();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _preset = _Preset.all;
    });
  }

  List<EmployeeModel> get _employees {
    final list = CacheService().getAllListenableEmployees().value
        .where((e) => (e.uid ?? '').isNotEmpty)
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _openStaffPicker() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _StaffPickerDialog(
        employees: _employees,
        selected: Set<String>.from(_staffIds),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _staffIds
        ..clear()
        ..addAll(result);
    });
  }

  // -------------------------------------------------------------- HELPERS

  static Color _hex(String raw, [Color fallback = const Color(0xFF0052D4)]) {
    var h = raw.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  String get _staffLabel {
    if (_staffIds.isEmpty) return 'All Follow-up Staff (${_employees.length})';
    final names = _employees
        .where((e) => _staffIds.contains(e.uid))
        .map((e) => e.name)
        .toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.length} staff selected';
  }

  String get _staffCaption => _staffIds.isEmpty
      ? 'All follow-up staff members included'
      : '${_staffIds.length} follow-up staff member(s) selected';

  String get _rangeLabel {
    if (_from == null && _to == null) return 'All time record';
    final a = _from == null ? '…' : _labelFmt.format(_from!);
    final b = _to == null ? '…' : _labelFmt.format(_to!);
    return '$a to $b';
  }

  // ---------------------------------------------------------------- BUILD

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterCard(wide),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard()
            else ...[
              _buildKpis(box.maxWidth),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildDistributionCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildShareCard()),
                  ],
                )
              else ...[
                _buildDistributionCard(),
                const SizedBox(height: 16),
                _buildShareCard(),
              ],
              const SizedBox(height: 16),
              _buildLeaderboard(),
            ],
          ],
        );
      },
    );
  }

  BoxDecoration _cardDecoration({Color? border, double width = 1}) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? scheme.outlineVariant, width: width),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(_error ?? '', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  // --------------------------------------------------------- FILTER CARD

  Widget _buildFilterCard(bool wide) {
    final scheme = Theme.of(context).colorScheme;

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.filter_alt, size: 16),
          label: const Text('Apply Filters'),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconBadge(Icons.stacked_bar_chart_rounded, const [Color(0xFF0052D4), Color(0xFF4364F7)]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deal Follow-up Performance & Status Graph',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Analyze deal status distribution by selecting one or multiple Follow-up Staff members and custom date ranges',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (wide) ...[const SizedBox(width: 12), actions],
      ],
    );

    final staffField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Follow-up Staff Members', badge: 'All Staff'),
        const SizedBox(height: 6),
        InkWell(
          onTap: _openStaffPicker,
          borderRadius: BorderRadius.circular(8),
          child: _fieldBox(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _staffLabel,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _staffCaption,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    Widget dateField(String label, DateTime? v, bool isFrom) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isFrom: isFrom),
          borderRadius: BorderRadius.circular(8),
          child: _fieldBox(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    v == null ? 'dd-mm-yyyy' : _dateFmt.format(v),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: v == null ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 14),
              ],
            ),
          ),
        ),
      ],
    );

    final presets = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Quick Presets'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _presetChip('All', _Preset.all),
            _presetChip('Today', _Preset.today),
            _presetChip('This Week', _Preset.thisWeek),
            _presetChip('This Month', _Preset.thisMonth),
            _presetChip('Last 30D', _Preset.last30),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (!wide) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: actions)],
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: staffField),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: dateField('From Date', _from, true)),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: dateField('To Date', _to, false)),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: presets),
              ],
            )
          else ...[
            staffField,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: dateField('From Date', _from, true)),
                const SizedBox(width: 12),
                Expanded(child: dateField('To Date', _to, false)),
              ],
            ),
            const SizedBox(height: 12),
            presets,
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {String? badge}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldBox({required Widget child}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _presetChip(String label, _Preset p) {
    final selected = _preset == p;
    return InkWell(
      onTap: () => _applyPreset(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D4ED8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF1D4ED8)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- KPIs

  Widget _buildKpis(double maxWidth) {
    final cols = maxWidth >= 900 ? 4 : (maxWidth >= 520 ? 2 : 1);
    final w = (maxWidth - (cols - 1) * 12) / cols;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: w,
          child: _kpi(
            title: 'TOTAL ASSIGNED DEALS',
            value: '${_summary.totalDeals}',
            caption: _rangeLabel,
            icon: Icons.work_outline,
            color: const Color(0xFF2563EB),
            outlined: false,
          ),
        ),
        SizedBox(
          width: w,
          child: _kpi(
            title: 'WON DEALS',
            value: '${_summary.wonDeals}',
            caption: 'Successfully closed deals',
            icon: Icons.emoji_events_outlined,
            color: const Color(0xFF16A34A),
            badge: '${_fmtPct(_summary.winRate)}% Win Rate',
          ),
        ),
        SizedBox(
          width: w,
          child: _kpi(
            title: 'IN-PROGRESS DEALS',
            value: '${_summary.activeDeals}',
            caption: 'Currently undergoing follow-up',
            icon: Icons.autorenew,
            color: const Color(0xFFF59E0B),
          ),
        ),
        SizedBox(
          width: w,
          child: _kpi(
            title: 'STAFF EVALUATED',
            value: '${_summary.staffCount}',
            caption: 'Follow-up assignees evaluated',
            icon: Icons.badge_outlined,
            color: const Color(0xFF06B6D4),
          ),
        ),
      ],
    );
  }

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _kpi({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
    String? badge,
    bool outlined = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        border: outlined ? color : scheme.outlineVariant,
        width: outlined ? 2 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: outlined ? color : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: outlined ? color : scheme.onSurface,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------- DISTRIBUTION CHART

  Widget _buildDistributionCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.bar_chart_rounded, const [Color(0xFF2563EB), Color(0xFF60A5FA)]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status-wise Deal Count Distribution',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Number of deals in each stage for selected follow-up staff',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _orientationToggle(),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _statuses.isEmpty
                ? const Center(child: Text('No status data'))
                : (_vertical ? _verticalBars() : _horizontalBars()),
          ),
        ],
      ),
    );
  }

  Widget _orientationToggle() {
    Widget seg(String label, IconData icon, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: selected ? const Color(0xFF475569) : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: selected ? Colors.white : null),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Vertical', Icons.bar_chart, _vertical, () => setState(() => _vertical = true)),
            seg('Horizontal', Icons.align_horizontal_left, !_vertical, () => setState(() => _vertical = false)),
          ],
        ),
      ),
    );
  }

  int get _maxCount =>
      _statuses.fold<int>(0, (m, s) => s.count > m ? s.count : m);

  Widget _verticalBars() {
    final scheme = Theme.of(context).colorScheme;
    final maxY = (_maxCount < 1 ? 1 : _maxCount).toDouble();
    final interval = (maxY / 4).ceilToDouble().clamp(1, 1000000).toDouble();
    final top = (((maxY * 1.1) / interval).ceil()) * interval;
    return BarChart(
      duration: const Duration(milliseconds: 500),
      BarChartData(
        maxY: top,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, gi, rod, ri) {
              final s = _statuses[group.x];
              return BarTooltipItem(
                '${s.name}\n',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '${s.count} deal(s)',
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (v, meta) => v != v.roundToDouble()
                  ? const SizedBox()
                  : Text(
                v.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= _statuses.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    _statuses[i].name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < _statuses.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _statuses[i].count.toDouble(),
                  width: 28,
                  color: const Color(0xFF1D5FD1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _horizontalBars() {
    final scheme = Theme.of(context).colorScheme;
    final maxV = (_maxCount < 1 ? 1 : _maxCount).toDouble();
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              for (final s in _statuses)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final w = c.maxWidth * (s.count / maxV);
                            final limit = c.maxWidth > 28 ? c.maxWidth - 28 : 0.0;
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    height: 18,
                                    width: w.clamp(0.0, limit).toDouble(),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D5FD1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${s.count}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 94),
            Text('0', style: _axisStyle(scheme)),
            Text((maxV / 2).toStringAsFixed(maxV >= 2 ? 0 : 1), style: _axisStyle(scheme)),
            Text('${maxV.toInt()}', style: _axisStyle(scheme)),
          ],
        ),
      ],
    );
  }

  TextStyle _axisStyle(ColorScheme s) => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: s.onSurfaceVariant,
  );

  // ---------------------------------------------------------- SHARE RATIO

  Widget _buildShareCard() {
    final scheme = Theme.of(context).colorScheme;
    final total = _statuses.fold<int>(0, (a, s) => a + s.count);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.donut_large_rounded, const [Color(0xFF10B981), Color(0xFF34D399)]),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Share Ratio',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Percentage breakdown',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: total == 0
                ? const Center(child: Text('No deals to show'))
                : PieChart(
                    duration: const Duration(milliseconds: 500),
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 58,
                      startDegreeOffset: -90,
                      sections: [
                        for (final s in _statuses)
                          if (s.count > 0)
                            PieChartSectionData(
                              value: s.count.toDouble(),
                              color: _hex(s.color),
                              radius: 24,
                              showTitle: false,
                            ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final s in _statuses)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _hex(s.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${s.count}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${total == 0 ? '0.0' : (s.count * 100 / total).toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- LEADERBOARD

  Widget _buildLeaderboard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.leaderboard_rounded, const [Color(0xFF7C3AED), Color(0xFFA855F7)]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow-up Staff Performance Leaderboard',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Individual staff deal distribution across statuses and win rates',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_staff.length} Staff Member${_staff.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_staff.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No staff data for the selected filters')),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                const heads = [
                  'Staff Member',
                  'Role',
                  'Total Deals',
                  'Status Breakdown',
                  'Won',
                  'Win Rate',
                  'Pipeline Value',
                  'Action',
                ];
                final width = c.maxWidth < 900 ? 900.0 : c.maxWidth;
                final headStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                );
                Widget pad(Widget w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Align(alignment: Alignment.centerLeft, child: w),
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(2.6),
                        1: FlexColumnWidth(1.3),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(0.8),
                        5: FlexColumnWidth(2),
                        6: FlexColumnWidth(1.6),
                        7: FlexColumnWidth(1.6),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.06),
                          ),
                          children: [
                            for (final h in heads) pad(Text(h, style: headStyle)),
                          ],
                        ),
                        for (final s in _staff)
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: scheme.outlineVariant),
                              ),
                            ),
                            children: [
                              for (final cell in _staffRow(s).cells) pad(cell.child),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  DataRow _staffRow(_StaffRow s) {
    final scheme = Theme.of(context).colorScheme;
    final photo = ApiConfig.resolveFileUrl(s.photo);
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  if (s.email.isNotEmpty)
                    Text(
                      s.email,
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s.role, style: const TextStyle(fontSize: 10)),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${s.total}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final e in s.statusCounts.entries)
                if (e.value > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _hex(_colorOf(e.key)).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${_nameOf(e.key)}: ${e.value}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _hex(_colorOf(e.key)),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        DataCell(
          Text(
            '${s.won}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF16A34A),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (s.winRate / 100).clamp(0, 1).toDouble(),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_fmtPct(s.winRate)}%', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        DataCell(
          Text(
            _money.format(s.pipeline),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        DataCell(
          OutlinedButton.icon(
            onPressed: s.uid.isEmpty || widget.onViewDeals == null
                ? null
                : () => widget.onViewDeals!(s.uid),
            icon: const Icon(Icons.visibility_outlined, size: 14),
            label: const Text('View Deals'),
            style: OutlinedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  String _nameOf(String statusUid) {
    if (statusUid == 'none') return 'No Status';
    return _statuses.where((s) => s.uid == statusUid).map((s) => s.name).firstOrNull ??
        'Status';
  }

  String _colorOf(String statusUid) {
    if (statusUid == 'none') return '#94A3B8';
    return _statuses.where((s) => s.uid == statusUid).map((s) => s.color).firstOrNull ??
        '#0052D4';
  }
}

// ---------------------------------------------------------------- MODELS

class _StatusRow {
  final String uid;
  final String name;
  final String color;
  final int count;
  const _StatusRow({
    required this.uid,
    required this.name,
    required this.color,
    required this.count,
  });

  factory _StatusRow.fromMap(Map<String, dynamic> m) => _StatusRow(
    uid: Js.s(m['uid']),
    name: Js.s(m['name']),
    color: Js.s(m['color'], '#0052D4'),
    count: Js.i(m['count']) ?? 0,
  );
}

class _StaffRow {
  final String uid;
  final String name;
  final String email;
  final String photo;
  final String role;
  final int total;
  final int won;
  final double winRate;
  final double pipeline;
  final Map<String, int> statusCounts;
  const _StaffRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.photo,
    required this.role,
    required this.total,
    required this.won,
    required this.winRate,
    required this.pipeline,
    required this.statusCounts,
  });

  factory _StaffRow.fromMap(Map<String, dynamic> m) {
    final raw = m['status_counts'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) => counts['$k'] = Js.i(v) ?? 0);
    }
    return _StaffRow(
      uid: Js.s(m['staff_uid']),
      name: Js.s(m['staff_name'], 'Unassigned'),
      email: Js.s(m['staff_email']),
      photo: Js.s(m['staff_photo']),
      role: Js.s(m['role_name'], 'Staff'),
      total: Js.i(m['total_deals']) ?? 0,
      won: Js.i(m['won_deals']) ?? 0,
      winRate: Js.d(m['win_rate']),
      pipeline: Js.d(m['pipeline_value']),
      statusCounts: counts,
    );
  }
}

class _Summary {
  final int totalDeals;
  final int wonDeals;
  final int activeDeals;
  final int staffCount;
  final double winRate;
  const _Summary({
    this.totalDeals = 0,
    this.wonDeals = 0,
    this.activeDeals = 0,
    this.staffCount = 0,
    this.winRate = 0,
  });

  factory _Summary.fromMap(Map<String, dynamic> m) => _Summary(
    totalDeals: Js.i(m['total_deals']) ?? 0,
    wonDeals: Js.i(m['won_deals']) ?? 0,
    activeDeals: Js.i(m['active_deals']) ?? 0,
    staffCount: Js.i(m['staff_count']) ?? 0,
    winRate: Js.d(m['win_rate']),
  );
}

// ---------------------------------------------------------- STAFF PICKER

class _StaffPickerDialog extends StatefulWidget {
  final List<EmployeeModel> employees;
  final Set<String> selected;
  const _StaffPickerDialog({required this.employees, required this.selected});

  @override
  State<_StaffPickerDialog> createState() => _StaffPickerDialogState();
}

class _StaffPickerDialogState extends State<_StaffPickerDialog> {
  late final Set<String> _sel = widget.selected;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final list = widget.employees
        .where((e) =>
            q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q))
        .toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Follow-up Staff',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search staff...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _sel.addAll(list.map((e) => e.uid!));
                    }),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(_sel.clear),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              Flexible(
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No staff found')),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final e = list[i];
                          final on = _sel.contains(e.uid);
                          final photo = ApiConfig.resolveFileUrl(e.profileImageUrl);
                          return CheckboxListTile(
                            dense: true,
                            value: on,
                            controlAffinity: ListTileControlAffinity.trailing,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _sel.add(e.uid!);
                              } else {
                                _sel.remove(e.uid);
                              }
                            }),
                            secondary: CircleAvatar(
                              radius: 15,
                              backgroundColor: scheme.primary.withValues(alpha: 0.15),
                              backgroundImage:
                                  photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                              child: photo.isEmpty
                                  ? Text(
                                      e.name.isEmpty ? '?' : e.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              e.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              e.email,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _sel),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Done (${_sel.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}