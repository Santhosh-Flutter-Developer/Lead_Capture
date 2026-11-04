import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class TaskViewColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
}

class TaskView extends StatefulWidget {
  final String uid;
  const TaskView({super.key, required this.uid});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> with TickerProviderStateMixin {
  late Future<TaskModel> _future;
  late TaskModel _taskModel;
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _vhScrollController = ScrollController();

  String? currentUid;
  String _cid = '';
  Stream<List<TaskCommentModel>>? _commentsStream;
  Stream<List<TaskHistoryModel>>? _historyStream;
  Stream<List<TaskTimeLogModel>>? _timeLogsStream;
  bool _isSending = false;
  bool isParticipant = false;
  bool _isActionLoading = false;
  int _statusFieldNonce = 0; // forces the status dropdown to rebuild/reset

  @override
  void initState() {
    super.initState();
    _future = TaskService.getTask(uid: widget.uid);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    Spdb.getUid().then((uid) {
      if (mounted) setState(() => currentUid = uid);
    });
    Spdb.getCid().then((cid) {
      if (mounted) {
        setState(() {
          _cid = cid ?? '';
          _commentsStream = TaskService.streamComments(
            cid: _cid,
            taskId: widget.uid,
          );
          _historyStream = TaskService.streamTaskHistory(
            cid: _cid,
            taskId: widget.uid,
          );
          _timeLogsStream = TaskService.streamTimeLogs(
            cid: _cid,
            taskId: widget.uid,
          );
        });
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _commentController.dispose();
    _vScrollController.dispose();
    _vhScrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment(String taskId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await TaskService.addComment(taskId: taskId, comment: text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, 'Failed to add comment', isSuccess: false);
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  /// Changes the task status from the dropdown.
  /// The service re-validates against the latest server state, so the rules
  /// (one active task, completed is final, etc.) can't be bypassed from here.
  Future<void> _changeStatus(TaskStatus target) async {
    if (_taskModel.uid == null) return;
    if (target == _taskModel.currentStatus) return;

    if (target == TaskStatus.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Mark as completed?"),
          content: const Text(
            "Once completed, the task is closed and its status can't be changed.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text("Complete"),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        // Reset the dropdown so it doesn't keep showing the cancelled value.
        setState(() => _statusFieldNonce++);
        return;
      }
    }

    setState(() => _isActionLoading = true);

    try {
      await TaskService.updateTaskStatus(
        taskId: _taskModel.uid!,
        newStatus: target,
      );

      final now = DateTime.now();
      setState(() {
        switch (target) {
          case TaskStatus.completed:
            _taskModel.completed = true;
            _taskModel.hasStarted = false;
            _taskModel.completedTime = now;
            break;
          case TaskStatus.started:
          case TaskStatus.inProgress:
            if (!_taskModel.hasStarted && _taskModel.startedTime == null) {
              _taskModel.startedTime = now;
            }
            _taskModel.hasStarted = true;
            _taskModel.completed = false;
            break;
          case TaskStatus.onHold:
          case TaskStatus.pending:
            break;
        }
        _taskModel.status = target.name;
      });

      if (!mounted) return;
      FlushBar.show(
        context,
        "Status updated to ${target.label}",
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      // Revert the dropdown to the real status.
      setState(() => _statusFieldNonce++);
      FlushBar.show(
        context,
        e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return AppColors.warning;
      case TaskStatus.started:
        return AppColors.info;
      case TaskStatus.inProgress:
        return AppColors.primary;
      case TaskStatus.onHold:
        return AppColors.blueGrey;
      case TaskStatus.completed:
        return AppColors.success;
    }
  }

  /// Which statuses can be chosen from the current one.
  /// A task that was never started can only be started; completing or holding
  /// it first would skip time tracking (same rule as the old Start button).
  bool _canMoveTo(TaskStatus current, TaskStatus target) {
    if (target == current) return true;
    if (current == TaskStatus.pending) {
      return target == TaskStatus.started || target == TaskStatus.inProgress;
    }
    return true;
  }

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Back(color: Colors.white),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Iconsax.task_square,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            "Task Details",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const WaitingLoading();

    return FutureBuilder<TaskModel>(
      future: _future,
      builder: (context, taskSnap) {
        if (taskSnap.connectionState == ConnectionState.waiting) {
          return const WaitingLoading();
        }
        if (!taskSnap.hasData) return ErrorDisplay(error: "Task not found");

        _taskModel = taskSnap.data!;
        isParticipant =
            currentUid != null &&
            (_taskModel.assignees.contains(currentUid!) ||
                _taskModel.createdBy.contains(currentUid!));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 1000;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: isWide ? 7 : 1,
                              child: Padding(
                                padding: const EdgeInsets.only(right:8.0),
                                child: Scrollbar(
                                                    controller: _vScrollController,
                                                    thumbVisibility: true,
                                                    interactive: true,
                                                    trackVisibility: true,
                                                    radius: const Radius.circular(8),
                                                    thickness: 8,
                                                    child: SingleChildScrollView(
                                    controller: _vScrollController,
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [_buildMainContent(isWide)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isWide)
                              Container(
                                width: 380,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: _buildSidePanel(),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTaskHeader(),
        const SizedBox(height: 24),
        // On narrow screens there is no side panel, so the status control
        // lives here, right under the title.
        if (!isWide && isParticipant) ...[
          _buildActionButtons(),
          const SizedBox(height: 24),
        ],
        _buildInfoGrid(),
        const SizedBox(height: 32),
        _buildSectionLabel("TASK DESCRIPTION"),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            _taskModel.description.isNotEmpty
                ? _taskModel.description
                : "No description provided for this task.",
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_taskModel.attachments.isNotEmpty) ...[
          _buildSectionLabel("ATTACHMENTS"),
          const SizedBox(height: 12),
          _buildAttachmentsGrid(),
          const SizedBox(height: 32),
        ],
        // Narrow screens: people (assigned / collaborators / observers) are
        // shown inline because the side panel is hidden.
        if (!isWide) ...[_buildPeopleCard(), const SizedBox(height: 32)],
        _buildModernTabs(),
      ],
    );
  }

  Widget _buildTaskHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _taskModel.highPriority
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      (_taskModel.highPriority
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _taskModel.highPriority ? Iconsax.flash : Iconsax.task,
                    size: 14,
                    color: _taskModel.highPriority
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _taskModel.highPriority ? "URGENT" : "STANDARD",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _taskModel.highPriority
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _taskModel.taskName,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (_taskModel.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _taskModel.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      "#$tag",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = _taskModel.currentStatus;
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final daysLeft =
        _taskModel.deadline?.difference(DateTime.now()).inDays ?? 0;
    final deadline = _infoBox(
      Iconsax.calendar_1,
      "Deadline",
      _taskModel.deadline?.formatDate ?? "No date",
      daysLeft < 0
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
    );
    final reminder = _infoBox(
      Iconsax.timer_1,
      "Reminder",
      _taskModel.reminder?.listingDateTime ?? "Disabled",
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, c) {
        // Side by side only when there's room; otherwise the values were cut
        // off ("30-09-2...").
        if (c.maxWidth < 520) {
          return Column(
            children: [deadline, const SizedBox(height: 12), reminder],
          );
        }
        return Row(
          children: [
            Expanded(child: deadline),
            const SizedBox(width: 16),
            Expanded(child: reminder),
          ],
        );
      },
    );
  }

  Widget _infoBox(IconData icon, String label, String val, Color accent) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    val,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAttachmentsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _taskModel.attachments.length,
      itemBuilder: (context, index) {
        final file = _taskModel.attachments[index];
        return InkWell(
          onTap: () => previewAttachment(context, file),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Iconsax.document_text,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${file.size} KB",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_circle_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) => TabBar(
            isScrollable: c.maxWidth < 520,
            tabAlignment: c.maxWidth < 520 ? TabAlignment.start : null,
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: "Comments"),
              Tab(text: "Activity History"),
              Tab(text: "Time Tracking"),
            ],
          ),
          ),
        ),
        const SizedBox(height: 20),
        // Only the visible tab is built: an IndexedStack sized every tab to
        // the tallest one (blank space) and kept the live timer running
        // while hidden.
        switch (_tabController.index) {
          0 => _buildCommentsTab(),
          1 => _buildHistoryTab(),
          _ => _buildTimeTrackingTab(),
        },
      ],
    );
  }

  Widget _buildCommentsTab() {
    return StreamBuilder<List<TaskCommentModel>>(
      stream: _commentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final comments = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentInput(),
            const SizedBox(height: 20),
            if (comments.isEmpty)
              _buildEmptyState(Iconsax.slash, "No comments yet.")
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _buildCommentItem(comments[index]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(TaskCommentModel comment) {
    final user = CacheService.getUserByUid(comment.userId);
    var userData = UserDataModel.fromEmptyMap();

    if (user is EmployeeModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: CacheService.designationByUid(user.designation)?.name,
        userType: UserType.employee,
      );
    } else if (user is AdminModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: user.email,
        userType: UserType.admin,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(userData: userData, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user?.name ?? "Collaborator",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      comment.timestamp.listingDateTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichCommentText(data: comment.comment),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return RichCommentEditor(
      controller: _commentController,
      isSending: _isSending,
      onSend: () => _addComment(_taskModel.uid!),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<TaskHistoryModel>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return _buildEmptyState(Iconsax.activity, "No activity recorded.");
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) =>
              _buildHistoryItem(history[index], index == history.length - 1),
        );
      },
    );
  }

  Widget _buildHistoryItem(TaskHistoryModel item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.updateDisposition,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "By ${CacheService.getUserByUid(item.userId)?.name ?? 'User'} • ${item.timestamp.listingDateTime}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.update != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.update!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTrackingTab() {
    final TimeTrackingState state;
    switch (_taskModel.currentStatus) {
      case TaskStatus.pending:
        state = TimeTrackingState.notStarted;
        break;
      case TaskStatus.started:
      case TaskStatus.inProgress:
        state = TimeTrackingState.running;
        break;
      case TaskStatus.onHold:
        state = TimeTrackingState.paused;
        break;
      case TaskStatus.completed:
        state = TimeTrackingState.stopped;
        break;
    }
    return TimeTrackingPanel(
      logsStream: _timeLogsStream,
      state: state,
      startedTime: _taskModel.startedTime,
      stoppedTime: _taskModel.completedTime,
      stoppedLabel: 'Completed',
      pausedNote: 'Timer is paused while the task is on hold',
      notStartedText: 'Task has not been started yet.',
      trackingHint: 'Time is tracked once the task is started.',
    );
  }

  /// Assigned to / Collaborators / Observers. Shared by the desktop side
  /// panel and the mobile inline card.
  List<Widget> _peopleSection() {
    return [
      _buildSectionLabel("ASSIGNED TO"),
      const SizedBox(height: 16),
      ..._taskModel.assignees.map(
        (u) => _buildProfileTile(u, "Lead Execution"),
      ),
      const SizedBox(height: 32),
      _buildSectionLabel("COLLABORATORS"),
      const SizedBox(height: 16),
      if (_taskModel.participants.isEmpty)
        _buildEmptyStateSmall("No participants")
      else
        ..._taskModel.participants.map(
          (u) => _buildProfileTile(u, "Participant"),
        ),
      const SizedBox(height: 32),
      _buildSectionLabel("OBSERVERS"),
      const SizedBox(height: 16),
      if (_taskModel.observers.isEmpty)
        _buildEmptyStateSmall("No observers")
      else
        ..._taskModel.observers.map((u) => _buildProfileTile(u, "Viewer")),
    ];
  }

  Widget _buildPeopleCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _peopleSection(),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Scrollbar(
                      controller: _vhScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: ListView(
          controller: _vhScrollController,
          padding: const EdgeInsets.all(24),
          children: [
            ..._peopleSection(),
            const SizedBox(height: 40),
            if (isParticipant) _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(String uid, String role) {
    final user = CacheService.getUserByUid(uid);
    var userData = UserDataModel.fromEmptyMap();

    if (user is EmployeeModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: CacheService.designationByUid(user.designation)?.name,
        userType: UserType.employee,
      );
    } else if (user is AdminModel) {
      userData = UserDataModel(
        name: user.name,
        uid: user.uid ?? '',
        profilePic: user.profileImageUrl,
        desc: user.email,
        userType: UserType.admin,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          UserAvatar(userData: userData, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? "System User",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_taskModel.completed) {
      return const Center(
        child: Text(
          "Task successfully closed.",
          style: TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    final current = _taskModel.currentStatus;
    final isPending = current == TaskStatus.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel("STATUS"),
        const SizedBox(height: 12),
        DropdownButtonFormField<TaskStatus>(
          key: ValueKey('task-status-$current-$_statusFieldNonce'),
          initialValue: isPending ? null : current,
          isExpanded: true,
          hint: const Text("Pending - select status"),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          items: TaskStatusX.selectable.map((s) {
            final enabled = _canMoveTo(current, s);
            final color = enabled
                ? _statusColor(s)
                : Theme.of(context).disabledColor;
            return DropdownMenuItem<TaskStatus>(
              value: s,
              enabled: enabled,
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: _isActionLoading
              ? null
              : (value) {
                  if (value != null) _changeStatus(value);
                },
        ),
        if (_isActionLoading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 40,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          msg,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
  Widget _buildEmptyStateSmall(String msg) => Text(
    msg,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    ),
  );
}