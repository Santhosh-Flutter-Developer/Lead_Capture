import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/services/services.dart';
import 'bloc/backup_bloc.dart';

class BackupColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}

class BackupListing extends StatefulWidget {
  const BackupListing({super.key});

  @override
  State<BackupListing> createState() => _BackupListingState();
}

class _BackupListingState extends State<BackupListing> {
  final BackupTrigger _trigger = BackupTrigger();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _vhScrollController = ScrollController();
  String _search = '';
  bool _busy = false;
  BackupModel? _selectedBackup;
  late BuildContext blocContext;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  final Map<String, List<String>> _exampleSubcollectionsMap = {
    'users': [
      'activityLogs',
      'admins',
      'chats',
      'clients',
      'dealStatus',
      'deals',
      'departments',
      'designations',
      'employees',
      'feed',
      'leadCategory',
      'leadStatus',
      'leads',
      'loginLogs',
      'notifications',
      'projects',
      'roles',
      'settings',
      'subDepartments',
      'tasks',
      'trash',
      'version',
    ],
    'chats': ['messages'],
    'tasks': ['taskHistory', 'taskComments'],
  };

  @override
  void dispose() {
    _vScrollController.dispose();
    _vhScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    blocContext.read<BackupBloc>().add(StreamBackup());
    await Future.delayed(const Duration(milliseconds: 350));
  }

  Map<String, List<BackupModel>> _groupByDay(List<BackupModel> items) {
    final Map<String, List<BackupModel>> map = {};
    final now = DateTime.now();

    for (final item in items) {
      final dt = item.timestamp;
      final diff = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

      String label;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == -1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(dt);
      }

      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'export':
        return const Color(0xFF6366F1); // indigo
      case 'import':
        return const Color(0xFF10B981); // green
      case 'auto':
      case 'scheduled':
        return const Color(0xFFF59E0B); // amber
      case 'manual':
        return const Color(0xFF06B6D4); // cyan
      default:
        return const Color(0xFF8B5CF6); // purple
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'export':
        return Iconsax.export_3;
      case 'import':
        return Iconsax.import_1;
      case 'auto':
      case 'scheduled':
        return Iconsax.clock;
      case 'manual':
        return Iconsax.finger_cricle;
      default:
        return Iconsax.cloud;
    }
  }

  Widget _avatar(String text, {double size = 48}) {
    final color = _typeColor(text);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(_typeIcon(text), color: Colors.white, size: size * 0.44),
    );
  }

  Widget _typePill(String type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            type.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportBackup(BuildContext context) async {
    final List<String> paths = ['/users/KUsgiMjuGIdmQBMhFKNJ/'];

    try {
      setState(() => _busy = true);

      final url = await _trigger.backupPaths(
        paths,
        subcollectionsMap: _exampleSubcollectionsMap,
      );

      if (!mounted) return;

      setState(() => _busy = false);

      if (url.isNotEmpty) {
        // Refresh list first
        blocContext.read<BackupBloc>().add(StreamBackup());

        // Small delay helps after bloc rebuild
        await Future.delayed(const Duration(milliseconds: 200));

        if (!mounted) return;

        await _showResultDialog(
          context,
          'Backup Success',
          'A new data snapshot has been created and uploaded to the secure vault.',
          url: url,
        );

        // Optional snackbar
        FlushBar.show(context, 'Backup created successfully', isSuccess: true);
      } else {
        FlushBar.show(
          context,
          'Backup completed but URL is empty',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);

      FlushBar.show(context, 'Export failed: $e', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupBloc()..add(StreamBackup()),
      child: Builder(
        builder: (context) {
          blocContext = context;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: BlocBuilder<BackupBloc, BackupState>(
                    builder: (context, state) {
                      if (state is BackupLoading) {
                        return const Center(child: WaitingLoading());
                      }
                      if (state is BackupError) {
                        return _buildErrorState(state.message);
                      }
                      if (state is BackupLoaded) {
                        final items = state.backups.where((b) {
                          if (_search.isEmpty) return true;
                          final s = _search.toLowerCase();
                          return b.path.toLowerCase().contains(s) ||
                              b.url.toLowerCase().contains(s);
                        }).toList();

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth > 1100;
                            return isDesktop
                                ? _buildDesktopLayout(items)
                                : _buildMobileLayout(items);
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        12,
        16,
      ),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.cloud, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Security Vault",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Manage cloud backups and data snapshots",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () =>
                  blocContext.read<BackupBloc>().add(StreamBackup()),
              icon: const Icon(Iconsax.refresh, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }

  /// DESKTOP LAYOUT: Master-Detail Split Pane
  Widget _buildDesktopLayout(List<BackupModel> backups) {
    final grouped = _groupByDay(backups);

    return Row(
      children: [
        // Master List
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: backups.isEmpty
                    ? _buildEmptyState()
                    : Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: ListView.builder(
                          controller: _vScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: grouped.length,
                            itemBuilder: (context, index) {
                              final entry = grouped.entries.elementAt(index);
                              return _buildGroupSection(
                                entry.key,
                                entry.value,
                                isDesktop: true,
                              );
                            },
                          ),
                      ),
                    ),
              ),
              _buildExportBar(),
            ],
          ),
        ),
        // Detail View
        Expanded(
          child: _selectedBackup == null
              ? _buildEmptyDetailView()
              : Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Scrollbar(
                      controller: _vhScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                    controller: _vhScrollController,
                      padding: const EdgeInsets.all(60),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _buildDetailContent(_selectedBackup!),
                        ),
                      ),
                    ),
                ),
              ),
        ),
      ],
    );
  }

  /// MOBILE LAYOUT: Traditional List View
  Widget _buildMobileLayout(List<BackupModel> backups) {
    final grouped = _groupByDay(backups);

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: backups.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _refresh(),
                  child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView.builder(
                      controller: _vScrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return _buildGroupSection(
                          entry.key,
                          entry.value,
                          isDesktop: false,
                        );
                      },
                    ),
                  ),
                ),
        ),
        _buildExportBar(isMobile: true),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v.trim()),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: _brandGradient),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(
                    Iconsax.search_normal_1,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            hintText: 'Filter registry...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildExportBar({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isMobile ? 32 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _brandGradient,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4364F7).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _busy ? null : () => exportBackup(blocContext),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.export_3, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    "Create New Snapshot",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

  Widget _buildGroupSection(
    String label,
    List<BackupModel> items, {
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _buildBackupItem(item, isDesktop)),
      ],
    );
  }

  Widget _buildBackupItem(BackupModel item, bool isDesktop) {
    final isSelected = _selectedBackup?.uid == item.uid;
    final color = _typeColor(item.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        onTap: () {
          if (isDesktop) {
            setState(() => _selectedBackup = item);
          } else {
            _showMobileDetailSheet(item);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _avatar(item.type, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _typePill(item.type),
                        const SizedBox(width: 8),
                        Icon(
                          Iconsax.clock,
                          size: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _timeAgo(item.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 14,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(BackupModel item) {
    final color = _typeColor(item.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              _avatar(item.type, size: 64),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.path,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _typePill(item.type),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _buildDetailSection("REGISTRY DETAILS", Iconsax.document_text, [
          _detailRow(
            Iconsax.calendar_1,
            "Timestamp",
            DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(item.timestamp),
          ),
          _detailRow(Iconsax.user, "UID", item.uid ?? ''),
        ]),
        const SizedBox(height: 32),
        _buildDetailSection("STORAGE VAULT URL", Iconsax.link, [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: SelectableText(
              item.url,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _brandGradient),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4364F7).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.url));
                  FlushBar.show(context, 'Link copied to clipboard');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.copy, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "Copy Link",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 60),
        const Divider(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Spacer(),
            Material(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _confirmDelete(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.trash,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Delete Record",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetailView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.cloud_sunny,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "Select a backup to view technical metadata",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileDetailSheet(BackupModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailContent(item),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResultDialog(
    BuildContext context,
    String title,
    String message, {
    String? url,
  }) {
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (url != null) ...[
              const SizedBox(height: 16),
              Text(
                "VAULT URL",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BackupModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Backup?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will remove the backup record from the registry. The storage file remains unaffected.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('backups')
          .doc(item.uid)
          .delete();
      if (!mounted) return;
      if (_selectedBackup?.uid == item.uid) {
        setState(() => _selectedBackup = null);
      }
      blocContext.read<BackupBloc>().add(StreamBackup());
      FlushBar.show(context, 'Record removed successfully');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.cloud_cross,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "Registry is empty",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create a new snapshot to begin.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String msg) {
    return Center(
      child: Text(
        "Connection Error: $msg",
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
