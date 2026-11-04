import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/services/services.dart';

class TaskCalendarListing extends StatefulWidget {
  final List<TaskModel> tasks;
  const TaskCalendarListing({super.key, required this.tasks});

  @override
  State<TaskCalendarListing> createState() => _TaskCalendarListingState();
}

class _TaskCalendarListingState extends State<TaskCalendarListing> {
  Calendar _currentView = Calendar.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  PermissionModel? _permissions;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Tasks');
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

  void _previousMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildViewSwitcher(),
          if (_currentView != Calendar.month) _buildHorizontalDatePicker(),
          _buildBody(widget.tasks),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
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
    bool isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = view),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF4364F7) : Colors.grey[600],
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
          DateTime date = DateTime.now().add(Duration(days: index - 3));
          bool isSelected = _isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4364F7) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.3),
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
                      color: isSelected ? Colors.white70 : Colors.grey[400],
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
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

  Widget _buildBody(List<TaskModel> tasks) {
    switch (_currentView) {
      case Calendar.day:
        return _buildDayView(tasks);
      case Calendar.week:
        return _buildWeekView(tasks);
      case Calendar.month:
        return _buildMonthView(tasks);
    }
  }

  Widget _buildDayView(List<TaskModel> tasks) {
    final dayTasks = tasks
        .where((e) => _isSameDay(e.deadline ?? DateTime.now(), _selectedDate))
        .toList();

    if (dayTasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            "No tasks for this day",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    var totalIndexes = [...dayTasks];

    // The calendar already lives inside a scrollable parent, so this list must
    // size itself to its content (shrinkWrap) and let the parent do the scrolling.
    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: totalIndexes.length,
      itemBuilder: (context, index) {
        final e = totalIndexes[index];

        return TaskEventCard(
          title: '#${e.taskNumber} ${e.taskName}',
          category: e.highPriority ? 'High Priority' : 'Low Priority',
          categoryColor: const Color(0xFFEAF0FE),
          textColor: const Color(0xFF4364F7),
          time: (e.deadline ?? DateTime.now()).formatDateTime,
          avatars: [
            ...(e.assignees),
            ...(e.observers),
            ...(e.participants),
            ...(e.createdBy),
          ],
          onTap: () {
            if (kIsDesktop) {
              GeneralDialog.showRTLSheet(context, TaskView(uid: e.uid ?? ''));
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskView(uid: e.uid ?? ''),
                ),
              );
            }
          },
          completed: e.completed,
        );
      },
    );
  }

  Widget _buildWeekView(List<TaskModel> tasks) {
    DateTime firstDayOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 7,
      itemBuilder: (context, index) {
        DateTime day = firstDayOfWeek.add(Duration(days: index));

        var taskCount = tasks
            .where((e) => _isSameDay(e.deadline ?? DateTime.now(), day))
            .length;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: InkWell(
            onTap: () async {
              if (taskCount == 0) {
                if (!(_permissions?.canCreate ?? false)) return;
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(
                    context,
                    TaskCreate(employees: []),
                  );
                } else {
                  Sheet.showSheet(context, widget: TaskCreate(employees: []));
                }
              } else {
                showInfoGeneralDialog(
                  context,
                  title: 'Tasks on ${day.day}/${day.month}/${day.year}',
                  description:
                      'You have $taskCount task(s) scheduled for this day.',

                  tasks: tasks
                      .where(
                        (e) => _isSameDay(e.deadline ?? DateTime.now(), day),
                      )
                      .toList(),
                );
              }
            },
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    taskCount == 0 ? "No tasks" : "$taskCount Tasks scheduled",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthView(List<TaskModel> tasks) {
    int daysInMonth = _getDaysInMonth(_focusedMonth.year, _focusedMonth.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const Icon(Iconsax.calendar_1, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              int dayNum = index + 1;
              DateTime date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNum,
              );
              bool isToday = _isSameDay(date, DateTime.now());

              final dayTasks = tasks
                  .where(
                    (e) => _isSameDay((e.deadline ?? DateTime.now()), date),
                  )
                  .toList();
              bool hasTasks = dayTasks.isNotEmpty;

              return InkWell(
                onTap: () async {
                  if (hasTasks) {
                    showInfoGeneralDialog(
                      context,
                      title: 'Tasks on ${date.day}/${date.month}/${date.year}',
                      description:
                          'You have ${dayTasks.length} tasks(s) scheduled for this day.',

                      tasks: tasks
                          .where(
                            (e) =>
                                _isSameDay(e.deadline ?? DateTime.now(), date),
                          )
                          .toList(),
                    );
                  } else {
                    if (!(_permissions?.canCreate ?? false)) return;
                    if (kIsDesktop) {
                      GeneralDialog.showRTLSheet(
                        context,
                        TaskCreate(employees: []),
                      );
                    } else {
                      Sheet.showSheet(
                        context,
                        widget: TaskCreate(employees: []),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF4364F7) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day Number Count Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '$dayNum',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isToday
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                            ),
                          ),
                          if (hasTasks)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(
                                        0xFF4364F7,
                                      ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${dayTasks.length}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: isToday
                                          ? Colors.white
                                          : const Color(0xFF4364F7),
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Names Scroll View
                      if (hasTasks)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...dayTasks.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '#${e.taskNumber} ${e.taskName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            height: 1.1,
                                            color: isToday
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : Colors.black87,
                                          ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
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

  void showInfoGeneralDialog(
    BuildContext context, {
    required String title,
    required String description,
    required List<TaskModel> tasks,
  }) {
    final totalItems = [...tasks];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// Description
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),

                  const SizedBox(height: 16),

                  /// Scrollable list
                  Expanded(
                    child: Scrollbar(
                      child: ListView.separated(
                        itemCount: totalItems.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          var item = totalItems[index];
                          return ListTile(
                            onTap: () {
                              Navigator.pop(context);
                              if (_permissions?.canEdit ?? false) {
                                if (kIsDesktop) {
                                  GeneralDialog.showRTLSheet(
                                    context,
                                    TaskEdit(uid: item.uid ?? ''),
                                  );
                                } else {
                                  Sheet.showSheet(
                                    context,
                                    widget: TaskEdit(uid: item.uid ?? ''),
                                  );
                                }
                              } else {
                                if (kIsDesktop) {
                                  GeneralDialog.showRTLSheet(
                                    context,
                                    TaskView(uid: item.uid ?? ''),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TaskView(uid: item.uid ?? ''),
                                    ),
                                  );
                                }
                              }
                            },
                            title: Text('#${item.taskNumber} ${item.taskName}'),
                            subtitle: Text(
                              item.description.isNotEmpty
                                  ? item.description
                                  : "No description",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Column(
                              children: [
                                Text(
                                  "Deadline",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  (item.deadline ?? DateTime.now()).formatTime,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "CLOSE",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },

      /// Animation
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

class TaskEventCard extends StatelessWidget {
  final String title;
  final String category;
  final Color categoryColor;
  final Color textColor;
  final String time;
  final List<String> avatars;
  final bool completed;
  final VoidCallback? onTap;

  const TaskEventCard({
    super.key,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.textColor,
    required this.time,
    required this.avatars,
    required this.completed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 30,
                  width: 100,
                  child: Stack(
                    children: List.generate(avatars.length, (index) {
                      final avatarUserId = avatars[index];
                      final avatarUrl = CacheService.getUserByUid(avatarUserId);

                      return Positioned(
                        left: index * 20.0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage: NetworkImage(
                              avatarUrl?.profileImageUrl ??
                                  AppStrings.emptyProfilePhotoUrl,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Icon(
                  Icons.check_circle_outline,
                  size: 24,
                  color: completed ? AppColors.success : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}