import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import 'loading.dart';
import '/theme/theme.dart';

/// Where a tracked item (task / ticket) currently is, as far as the timer is
/// concerned.
enum TimeTrackingState { notStarted, running, paused, stopped }

/// Time tracking tab, shared by tasks and tickets.
///
/// Time is the sum of the real work sessions (`...TimeLogs` records): a session
/// opens when work starts/resumes and closes when it is paused or finished. So:
///  * running  -> the clock ticks every second.
///  * paused   -> the clock is frozen (paused time is not counted).
///  * stopped  -> the clock is stopped (completed / resolved).
class TimeTrackingPanel extends StatefulWidget {
  final Stream<List<TaskTimeLogModel>>? logsStream;
  final TimeTrackingState state;

  /// Only used for old items that have no session records.
  final DateTime? startedTime;

  /// When the item was completed/resolved. Falls back to the end of the last
  /// session when null.
  final DateTime? stoppedTime;

  /// "Completed" (tasks) / "Resolved" (tickets).
  final String stoppedLabel;

  /// Shown under the clock while paused.
  final String pausedNote;

  /// Empty-state texts.
  final String notStartedText;
  final String trackingHint;

  const TimeTrackingPanel({
    super.key,
    required this.logsStream,
    required this.state,
    this.startedTime,
    this.stoppedTime,
    this.stoppedLabel = 'Completed',
    this.pausedNote = 'Timer is paused',
    this.notStartedText = 'Not started yet.',
    this.trackingHint = 'Time is tracked once work has started.',
  });

  @override
  State<TimeTrackingPanel> createState() => _TimeTrackingPanelState();
}

class _Session {
  final DateTime start;
  final DateTime end;
  final bool live;
  final String userId;
  const _Session(this.start, this.end, this.live, this.userId);
  Duration get duration => end.difference(start);
}

class _TimeTrackingPanelState extends State<TimeTrackingPanel> {
  static const int _collapsedSessions = 5;

  Timer? _ticker;
  DateTime _now = DateTime.now();
  // When the task stopped running during this screen's lifetime. Only used to
  // close a session whose end time hasn't reached us from the server yet.
  DateTime? _pausedAt;
  bool _showAllSessions = false;

  bool get _running => widget.state == TimeTrackingState.running;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant TimeTrackingPanel old) {
    super.didUpdateWidget(old);
    final wasRunning = old.state == TimeTrackingState.running;
    if (wasRunning && !_running) _pausedAt = DateTime.now();
    if (_running) _pausedAt = null;
    _syncTicker();
  }

  void _syncTicker() {
    if (_running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  List<_Session> _buildSessions(List<TaskTimeLogModel> logs) {
    DateTime openEnd(DateTime start) {
      if (_running) return _now;
      // Not running but the session is still open => it ended when the task
      // was completed / paused; never keep counting.
      return widget.stoppedTime ?? _pausedAt ?? start;
    }

    _Session make(DateTime start, DateTime? end, String uid) {
      final isLive = end == null && _running;
      var e = end ?? openEnd(start);
      if (e.isBefore(start)) e = start;
      return _Session(start, e, isLive, uid);
    }

    if (logs.isEmpty) {
      // Older tasks that have no logs: fall back to started/completed times.
      final s = widget.startedTime;
      if (s == null) return const [];
      return [make(s, widget.stoppedTime, '')];
    }
    final sorted = [...logs]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return [for (final l in sorted) make(l.startTime, l.endTime, l.userId)];
  }

  /// Splits sessions at midnight so every day gets its own share.
  Map<DateTime, Duration> _byDay(List<_Session> sessions) {
    final out = <DateTime, Duration>{};
    for (final s in sessions) {
      var cur = s.start;
      while (cur.isBefore(s.end)) {
        final day = DateTime(cur.year, cur.month, cur.day);
        final next = DateTime(cur.year, cur.month, cur.day + 1);
        final segEnd = s.end.isBefore(next) ? s.end : next;
        out[day] = (out[day] ?? Duration.zero) + segEnd.difference(cur);
        cur = segEnd;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 338:05:09 (hours are not wrapped at 24, like a stopwatch)
  static String _clock(Duration d) =>
      '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

  static String _short(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${_two(d.inMinutes % 60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${_two(d.inSeconds % 60)}s';
    return '${d.inSeconds}s';
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final stream = widget.logsStream;
    if (stream == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: WaitingLoading(),
      );
    }
    return StreamBuilder<List<TaskTimeLogModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final sessions = _buildSessions(snap.data ?? const []);
        if (sessions.isEmpty) return _empty(context);

        final stopped = widget.state == TimeTrackingState.stopped;

        final active = sessions.fold<Duration>(
          Duration.zero,
          (sum, s) => sum + s.duration,
        );
        final first = sessions.first.start;
        final lastEnd = sessions.last.end;
        final stoppedAt = stopped ? (widget.stoppedTime ?? lastEnd) : null;
        final wallEnd = stoppedAt ?? (_running ? _now : lastEnd);
        var paused = wallEnd.difference(first) - active;
        if (paused.isNegative) paused = Duration.zero;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context, active, stoppedAt),
            const SizedBox(height: 16),
            _statTiles(context, first, stoppedAt, sessions.length, paused),
            const SizedBox(height: 28),
            _label(context, 'WORK SESSIONS'),
            const SizedBox(height: 12),
            _sessionList(context, sessions),
            const SizedBox(height: 28),
            _label(context, 'DAILY BREAKDOWN'),
            const SizedBox(height: 12),
            _dailyBreakdown(context, sessions),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Iconsax.timer_start, size: 40, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            widget.state == TimeTrackingState.notStarted
                ? widget.notStartedText
                : 'No time has been recorded yet.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            widget.trackingHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 1.5,
    ),
  );

  Widget _hero(BuildContext context, Duration active, DateTime? stoppedAt) {
    final Color color;
    final IconData icon;
    final String badge;
    final String note;
    switch (widget.state) {
      case TimeTrackingState.stopped:
        color = AppColors.success;
        icon = Iconsax.tick_circle;
        badge = widget.stoppedLabel.toUpperCase();
        note = stoppedAt == null
            ? 'Timer stopped'
            : 'Timer stopped - ${widget.stoppedLabel.toLowerCase()} ${stoppedAt.listingDateTime}';
        break;
      case TimeTrackingState.paused:
        color = AppColors.warning;
        icon = Iconsax.pause_circle;
        badge = 'PAUSED';
        note = widget.pausedNote;
        break;
      default:
        color = AppColors.primary;
        icon = Iconsax.timer_1;
        badge = 'TRACKING';
        note = 'Timer is running';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ACTIVE TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _badge(badge, color),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _clock(active),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    final running = _running;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running) ...[
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _now.second.isEven ? 1 : 0.25,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTiles(
    BuildContext context,
    DateTime first,
    DateTime? stoppedAt,
    int count,
    Duration paused,
  ) {
    final tiles = <Widget>[
      _tile(context, Iconsax.play, 'First started', first.listingDateTime),
      _tile(
        context,
        Iconsax.tick_circle,
        widget.stoppedLabel,
        stoppedAt?.listingDateTime ?? '--',
      ),
      _tile(context, Iconsax.layer, 'Work sessions', '$count'),
      _tile(context, Iconsax.pause, 'Time on hold', _short(paused)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 760 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
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
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionList(BuildContext context, List<_Session> sessions) {
    final scheme = Theme.of(context).colorScheme;
    // Newest first, numbered by the order they happened.
    final numbered = [
      for (var i = 0; i < sessions.length; i++) (i + 1, sessions[i]),
    ].reversed.toList();
    final visible = _showAllSessions
        ? numbered
        : numbered.take(_collapsedSessions).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _sessionRow(context, visible[i].$1, visible[i].$2),
          ],
          if (numbered.length > _collapsedSessions) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            TextButton(
              onPressed: () =>
                  setState(() => _showAllSessions = !_showAllSessions),
              child: Text(
                _showAllSessions
                    ? 'Show less'
                    : 'Show all ${numbered.length} sessions',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionRow(BuildContext context, int n, _Session s) {
    final scheme = Theme.of(context).colorScheme;
    final who = s.userId.isEmpty
        ? null
        : CacheService.getUserByUid(s.userId)?.name;
    final endText = s.live ? 'Running' : s.end.listingDateTime;
    final color = s.live ? AppColors.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.start.listingDateTime}  \u2192  $endText',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (who != null && who.isNotEmpty)
                  Text(
                    who,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _short(s.duration),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: s.live ? AppColors.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyBreakdown(BuildContext context, List<_Session> sessions) {
    final scheme = Theme.of(context).colorScheme;
    final byDay = _byDay(sessions);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final shown = days.take(7).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    var maxSecs = 1;
    for (final d in shown) {
      if (byDay[d]!.inSeconds > maxSecs) maxSecs = byDay[d]!.inSeconds;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final d in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      d.formatDateMonth,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: byDay[d]!.inSeconds / maxSecs,
                        minHeight: 10,
                        backgroundColor: scheme.primary.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _short(byDay[d]!),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (days.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Showing the last ${shown.length} of ${days.length} days',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}