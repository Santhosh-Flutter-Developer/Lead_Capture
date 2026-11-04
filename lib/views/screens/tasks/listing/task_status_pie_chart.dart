import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:leadcapture/utils/src/platform.dart';
import 'package:leadcapture/views/components/src/sheet.dart';
import 'package:leadcapture/views/screens/tasks/listing/tasks_listing.dart';
import 'package:leadcapture/views/ui/src/general_dialog.dart';
import '/models/models.dart';

class TaskStatusPieChart extends StatefulWidget {
  /// The list of tasks to be categorized and visualized.
  final List<TaskModel> tasks;

  const TaskStatusPieChart({super.key, required this.tasks});

  @override
  State<TaskStatusPieChart> createState() => _TaskStatusPieChartState();
}

class _TaskStatusPieChartState extends State<TaskStatusPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 1. Grouping Logic
    int notStartedCount = 0;
    int ongoingCount = 0;
    int completedCount = 0;

    for (var task in widget.tasks) {
      if (task.completed == true) {
        completedCount++;
      } else if (task.hasStarted == true && task.completed == false) {
        ongoingCount++;
      } else if (task.hasStarted == false && task.completed == false) {
        notStartedCount++;
      }
    }

    final totalTasks = widget.tasks.length;

    return GestureDetector(
      onTap: () {
        if (kIsMobile || width < 1000) {
          Sheet.showSheet(context, widget: const TasksListing());
        } else {
          GeneralDialog.showRTLSheet(context, const TasksListing());
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
                          colors: [Color(0xFF10B981), Color(0xFF6EE7B7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.donut_large_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Task Distribution",
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
                  "Progress overview for $totalTasks active tasks",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: isDesktop ? 280 : 400,
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildPieChart(
                                notStartedCount,
                                ongoingCount,
                                completedCount,
                              ),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 1,
                              child: _buildLegend(
                                notStartedCount,
                                ongoingCount,
                                completedCount,
                                totalTasks,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: _buildPieChart(
                                notStartedCount,
                                ongoingCount,
                                completedCount,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildLegend(
                              notStartedCount,
                              ongoingCount,
                              completedCount,
                              totalTasks,
                            ),
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

  Widget _buildPieChart(int notStarted, int ongoing, int completed) {
    final total = notStarted + ongoing + completed;
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
            centerSpaceRadius: 60,
            sections: _generateSections(notStarted, ongoing, completed),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              "Tasks",
              style: TextStyle(
                fontSize: 11,
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
    int notStarted,
    int ongoing,
    int completed,
  ) {
    // Pro Palette
    final List<Color> colors = [
      const Color(0xFF94A3B8), // Not Started - Slate
      const Color(0xFF2563EB), // Ongoing - Blue
      const Color(0xFF10B981), // Completed - Green
    ];

    final values = [
      notStarted.toDouble(),
      ongoing.toDouble(),
      completed.toDouble(),
    ];

    return List.generate(3, (i) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 45.0 : 35.0;
      final widgetSize = isTouched ? 16.0 : 12.0;

      // Don't show section if value is 0
      if (values[i] == 0) {
        return PieChartSectionData(value: 0, showTitle: false);
      }

      return PieChartSectionData(
        color: colors[i],
        value: values[i],
        title: values[i].toInt().toString(),
        radius: radius,
        titleStyle: TextStyle(
          fontSize: widgetSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildLegend(int notStarted, int ongoing, int completed, int total) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(
            "Not Started",
            notStarted,
            total,
            const Color(0xFF94A3B8),
          ),
          _legendItem("Ongoing", ongoing, total, const Color(0xFF2563EB)),
          _legendItem("Completed", completed, total, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _legendItem(String label, int count, int total, Color color) {
    final double percentage = total > 0 ? (count / total * 100) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  "$count Tasks",
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${percentage.toStringAsFixed(0)}%",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}