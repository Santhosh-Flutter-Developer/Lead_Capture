import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';

const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

class DealsCalendarListing extends StatefulWidget {
  final List<DealModel> dealList;
  final VoidCallback? onDealCreated;
  const DealsCalendarListing({
    super.key,
    required this.dealList,
    this.onDealCreated,
  });

  @override
  State<DealsCalendarListing> createState() => _DealsCalendarListingState();
}

class _DealsCalendarListingState extends State<DealsCalendarListing> {
  Calendar _currentView = Calendar.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  final ScrollController _vhScrollController = ScrollController();
  PermissionModel? _permissions;

  /// Decided from the available width (not the platform) so web / narrow
  /// windows use the same compact layout as a phone.
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _vhScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Deals');
    if (mounted) setState(() {});
  }

  // --- HELPERS ---

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    return DateFormat('MMMM').format(DateTime(2024, month));
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Locked (closed) deals use the brand blue, open deals use green.
  Color _accentFor(DealModel deal) =>
      deal.isLocked ? const Color(0xFF4364F7) : AppColors.success;

  void _previousMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  Future<void> _openDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _focusedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _focusedMonth = DateTime(pickedDate.year, pickedDate.month);
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _openDealCreate() async {
    if (!(_permissions?.canCreate ?? false)) return;
    final result = kIsDesktop
        ? await GeneralDialog.showRTLSheet(context, const DealCreate())
        : await Sheet.showSheet(context, widget: const DealCreate());
    if (result == true && mounted) {
      widget.onDealCreated?.call();
    }
  }

  void _openDealView(DealModel deal) {
    if (kIsDesktop) {
      GeneralDialog.showRTLSheet(context, DealsViewPage(deal: deal));
    } else {
      Sheet.showSheet(context, widget: DealsViewPage(deal: deal));
    }
  }

  void _openDealEdit(String uid) {
    if (kIsDesktop) {
      GeneralDialog.showRTLSheet(context, DealEdit(uid: uid));
    } else {
      Sheet.showSheet(context, widget: DealEdit(uid: uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _compact = box.maxWidth < 560;
        return Column(
          children: [
            _buildViewSwitcher(),
            if (_currentView != Calendar.month) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _circleIconButton(
                      icon: Iconsax.calendar_1,
                      onPressed: _openDatePicker,
                    ),
                  ],
                ),
              ),
              _buildHorizontalDatePicker(),
            ],
            _buildBody(widget.dealList),
          ],
        );
      },
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            _buildSwitchTab('Day', Calendar.day),
            _buildSwitchTab('Week', Calendar.week),
            _buildSwitchTab('Month', Calendar.month),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTab(String label, Calendar view) {
    final isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: _brandGradient)
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDatePicker() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index - 3));
          final isSelected = _isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _brandGradient,
                      )
                    : null,
                color: isSelected
                    ? null
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? null
                    : Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<DealModel> deals) {
    switch (_currentView) {
      case Calendar.day:
        return _buildDayView(deals);
      case Calendar.week:
        return _buildWeekView(deals);
      case Calendar.month:
        return _buildMonthView(deals);
    }
  }

  // ------------------------------------------------------------------ DAY

  Widget _buildDayView(List<DealModel> deals) {
    final dayDeals = deals
        .where((e) => _isSameDay(e.createdAt, _selectedDate))
        .toList();

    if (dayDeals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.calendar_remove,
                size: 44,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                "No deals for this day",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: dayDeals.length,
      itemBuilder: (context, index) {
        final e = dayDeals[index];
        final accent = _accentFor(e);
        return DealCard(
          title: e.dealName,
          category: (e.clientName != null && e.clientName!.isNotEmpty)
              ? e.clientName!
              : (e.companyName != null && e.companyName!.isNotEmpty)
              ? e.companyName!
              : 'Deal',
          categoryColor: accent.withValues(alpha: 0.12),
          textColor: accent,
          accentColor: accent,
          time: e.createdAt.formatDateTime,
          avatars: [e.createdBy.uid],
          onTap: () => _openDealView(e),
          completed: e.isLocked,
        );
      },
    );
  }

  // ----------------------------------------------------------------- WEEK

  Widget _buildWeekView(List<DealModel> deals) {
    final firstDayOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = firstDayOfWeek.add(Duration(days: index));
        final isToday = _isSameDay(day, DateTime.now());
        final dayDeals = deals
            .where((e) => _isSameDay(e.createdAt, day))
            .toList();
        final count = dayDeals.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday
                  ? const Color(0xFF4364F7).withValues(alpha: 0.4)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (count == 0) {
                  await _openDealCreate();
                } else {
                  showInfoGeneralDialog(
                    context,
                    title: 'Deals on ${day.day}/${day.month}/${day.year}',
                    description: 'You have $count deal(s) created for this day.',
                    items: dayDeals,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isToday
                            ? const LinearGradient(colors: _brandGradient)
                            : null,
                        color: isToday
                            ? null
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E').format(day),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? AppColors.white.withValues(alpha: 0.85)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          Text(
                            '${day.day}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? AppColors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        count == 0
                            ? "No deals"
                            : "$count deal${count == 1 ? '' : 's'} created",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: count == 0
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- MONTH

  Widget _buildMonthView(List<DealModel> deals) {
    final daysInMonth = _getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );

    return Padding(
      padding: EdgeInsets.all(_compact ? 14 : 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleIconButton(
                      icon: Icons.chevron_left,
                      onPressed: _previousMonth,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _circleIconButton(
                      icon: Icons.chevron_right,
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _circleIconButton(
                icon: Iconsax.calendar_1,
                onPressed: _openDatePicker,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: _compact ? 6 : 10,
              crossAxisSpacing: _compact ? 6 : 10,
              childAspectRatio: _compact ? 0.8 : 1,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final dayNum = index + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNum,
              );
              final isToday = _isSameDay(date, DateTime.now());
              final dayDeals = deals
                  .where((e) => _isSameDay(e.createdAt, date))
                  .toList();
              final hasDeals = dayDeals.isNotEmpty;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (hasDeals) {
                    showInfoGeneralDialog(
                      context,
                      title: 'Deals on ${date.day}/${date.month}/${date.year}',
                      description:
                          'You have ${dayDeals.length} deal(s) created for this day.',
                      items: dayDeals,
                    );
                  } else {
                    await _openDealCreate();
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(_compact ? 3 : 5),
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _brandGradient,
                          )
                        : null,
                    color: isToday
                        ? null
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF4364F7,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: _compact
                      ? _monthCellCompact(dayNum, isToday, dayDeals)
                      : _monthCellWide(dayNum, isToday, dayDeals),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _monthCellCompact(int dayNum, bool isToday, List<DealModel> dayDeals) {
    const maxDots = 3;
    final shown = dayDeals.take(maxDots).toList();
    final remaining = dayDeals.length - shown.length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$dayNum',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: isToday
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (dayDeals.isNotEmpty) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final deal in shown)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : _accentFor(deal),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+$remaining',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? Colors.white.withValues(alpha: 0.9)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _monthCellWide(int dayNum, bool isToday, List<DealModel> dayDeals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$dayNum',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isToday
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (dayDeals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.white.withValues(alpha: 0.24)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${dayDeals.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (dayDeals.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in dayDeals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isToday ? Colors.white : _accentFor(e),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.dealName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    height: 1.1,
                                    color: isToday
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Theme.of(context).colorScheme.onSurface,
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
    );
  }

  // --------------------------------------------------------------- DIALOG

  Widget _dialogTile(DealModel item) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accentFor(item);
    final canEdit = (_permissions?.canEdit ?? false) && !item.isLocked;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pop(context);
            _openDealView(item);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    item.isLocked ? Iconsax.lock : Iconsax.briefcase,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.dealName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (item.companyName != null &&
                                item.companyName!.isNotEmpty)
                            ? item.companyName!
                            : item.createdBy.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.dealValue > 0)
                      Text(
                        '₹${NumberFormat('#,##,###').format(item.dealValue)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      item.createdAt.formatTime,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (canEdit) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _openDealEdit(item.uid ?? '');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showInfoGeneralDialog(
    BuildContext context, {
    required String title,
    required String description,
    required List<DealModel> items,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width > 640 ? 560 : size.width * 0.92,
              height: size.height * 0.72,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: _brandGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.briefcase,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Scrollbar(
                      controller: _vhScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: ListView.builder(
                        controller: _vhScrollController,
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _dialogTile(items[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_permissions?.canCreate ?? false)
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: _brandGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.pop(context);
                                _openDealCreate();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Create Deal',
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "CLOSE",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  }
}

class DealCard extends StatelessWidget {
  final String title;
  final String category;
  final Color categoryColor;
  final Color textColor;
  final String time;
  final List<String> avatars;
  final bool completed;
  final VoidCallback? onTap;
  final Color? accentColor;

  const DealCard({
    super.key,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.textColor,
    required this.time,
    required this.completed,
    this.avatars = const [],
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = accentColor ?? textColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: barColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Iconsax.briefcase,
                                        size: 12,
                                        color: textColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          category,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                completed
                                    ? Icons.lock_outline
                                    : Icons.check_circle_outline,
                                size: 22,
                                color: completed
                                    ? AppColors.success
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 15,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  time,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (avatars.isNotEmpty)
                                SizedBox(
                                  height: 28,
                                  width: 28 + (avatars.length - 1) * 18.0,
                                  child: Stack(
                                    children: List.generate(avatars.length, (i) {
                                      final user = CacheService.getUserByUid(
                                        avatars[i],
                                      );
                                      return Positioned(
                                        left: i * 18.0,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundImage: NetworkImage(
                                              user?.profileImageUrl ??
                                                  AppStrings
                                                      .emptyProfilePhotoUrl,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}