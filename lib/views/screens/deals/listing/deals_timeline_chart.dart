import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/utils/src/platform.dart';
import 'package:leadcapture/views/components/src/sheet.dart';
import 'package:leadcapture/views/screens/deals/listing/deals_listing.dart';
import 'package:leadcapture/views/ui/src/general_dialog.dart';
import '/models/models.dart';

class DealsTimelineChart extends StatelessWidget {
  /// The list of deals to be visualized.
  final List<DealModel> deals;

  const DealsTimelineChart({super.key, required this.deals});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 1. Setup Current Month Data
    final DateTime now = DateTime.now();
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final String monthName = DateFormat('MMMM').format(now);

    // Initialize map for all days of the current month
    final Map<int, int> dayCounts = {
      for (int i = 1; i <= daysInMonth; i++) i: 0,
    };

    // Populate with actual deal counts for the current month
    for (var deal in deals) {
      if (deal.createdAt.year == now.year &&
          deal.createdAt.month == now.month) {
        final day = deal.createdAt.day;
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
    }

    // 2. Create Spots for LineChart
    final List<FlSpot> spots = dayCounts.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    // Calculate max Y for scaling
    double maxY =
        dayCounts.values.fold(0, (max, e) => e > max ? e : max).toDouble() + 1;
    if (maxY < 5) maxY = 5; // Minimum scale for aesthetics

    final theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      onTap: () {
        if (kIsMobile || width < 1000) {
          Sheet.showSheet(context, widget: const DealsListing());
        } else {
          GeneralDialog.showRTLSheet(context, const DealsListing());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Deals $monthName Activity",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Daily deal creation performance for the current month",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Live Data",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 320,
              child: LineChart(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          // Logic to show specific labels to avoid clutter
                          // Shows 1, 5, 10, 15, 20, 25, and last day
                          bool isStandardInterval =
                              day % 5 == 0 || day == 1 || day == daysInMonth;

                          if (isStandardInterval) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 12,
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: (maxY / 4).clamp(1, 100),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Theme.of(context).colorScheme.inverseSurface,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            'Day ${barSpot.x.toInt()}\n',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: '${barSpot.y.toInt()} New Deals',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.4,
                      preventCurveOverShooting: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Created Deals",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}