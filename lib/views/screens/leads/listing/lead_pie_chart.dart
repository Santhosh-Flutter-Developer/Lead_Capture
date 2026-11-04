import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:leadcapture/utils/src/platform.dart';
import 'package:leadcapture/views/components/src/sheet.dart';
import 'package:leadcapture/views/screens/leads/listing/lead_listing.dart';
import 'package:leadcapture/views/ui/src/general_dialog.dart';
import '/models/models.dart';

class LeadsSourcePieChart extends StatefulWidget {
  final List<LeadModel> leads;

  const LeadsSourcePieChart({super.key, required this.leads});

  @override
  State<LeadsSourcePieChart> createState() => _LeadsSourcePieChartState();
}

class _LeadsSourcePieChartState extends State<LeadsSourcePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 1. Group data by Lead Source
    final Map<String, int> sourceCounts = {};
    for (var lead in widget.leads) {
      final sourceName = lead.leadSource.name;
      sourceCounts[sourceName] = (sourceCounts[sourceName] ?? 0) + 1;
    }

    final totalLeads = widget.leads.length;

    return GestureDetector(
      onTap: () {
        if (kIsMobile || width < 1000) {
          Sheet.showSheet(context, widget: const LeadsListing());
        } else {
          GeneralDialog.showRTLSheet(context, const LeadsListing());
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 600;

          final theme = Theme.of(context);
          final bool isLight = theme.brightness == Brightness.light;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.5,
                ),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Leads by Source",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Distribution across $totalLeads total leads",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // We use a SizedBox instead of Expanded so it can fit inside a Column/ListView
                SizedBox(
                  height: isDesktop ? 300 : 450,
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildPieChart(sourceCounts, totalLeads),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 1,
                              child: _buildLegend(sourceCounts, totalLeads),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: _buildPieChart(sourceCounts, totalLeads),
                            ),
                            const SizedBox(height: 20),
                            _buildLegend(sourceCounts, totalLeads),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data, int total) {
    if (data.isEmpty) {
      return const Center(child: Text("No data available"));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 4,
            centerSpaceRadius: 50,
            sections: _generateSections(data, total),
          ),
        ),
        // Total count centered inside the donut hole.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toString(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              "Total",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _generateSections(
    Map<String, int> data,
    int total,
  ) {
    final List<Color> palette = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    int index = 0;
    return data.entries.map((entry) {
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 70.0 : 60.0;
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final color = palette[index % palette.length];

      index++;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> data, int total) {
    final List<Color> palette = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    int index = 0;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((entry) {
          final color = palette[index % palette.length];
          index++;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}