import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:leadcapture/theme/theme.dart';
import 'package:leadcapture/utils/src/open_file.dart';
import 'package:leadcapture/views/screens/download/bloc/download_bloc.dart';
import 'package:leadcapture/views/screens/download/bloc/download_event.dart';
import 'package:leadcapture/views/screens/download/bloc/download_state.dart';
import 'package:leadcapture/views/ui/src/back.dart';
import 'package:leadcapture/views/ui/src/loading.dart';

class DownloadHistory extends StatefulWidget {
  final bool showAppbar;

  const DownloadHistory({super.key, required this.showAppbar});

  @override
  State<DownloadHistory> createState() => _DownloadHistoryState();
}

class _DownloadHistoryState extends State<DownloadHistory> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();

  String _search = '';

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    context.read<DownloadHistoryBloc>().add(StreamDownloadHistory());
  }

  Map<String, List<DownloadHistoryModel>> _groupByDay(
    List<DownloadHistoryModel> items,
  ) {
    final Map<String, List<DownloadHistoryModel>> map = {};
    final now = DateTime.now();
    for (final item in items) {
      final dt = item.downloadedAt;
      final difference = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

      String label;
      if (difference == 0) {
        label = 'Today';
      } else if (difference == -1) {
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
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DownloadHistoryBloc()..add(StreamDownloadHistory()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.showAppbar
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Back(color: Theme.of(context).colorScheme.onSurface),
                ),
                title: Text(
                  "Download History",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: _buildHeaderSearch(),
                ),
              )
            : null,
        body: BlocBuilder<DownloadHistoryBloc, DownloadHistoryState>(
          builder: (context, state) {
            if (state is DownloadHistoryLoading) {
              return const Center(child: WaitingLoading());
            }
            if (state is DownloadHistoryError) {
              return Center(child: Text(state.message));
            }
            if (state is DownloadHistoryLoaded) {
              final filteredList = state.items.where((it) {
                if (_search.isEmpty) return true;
                return it.fileName.toLowerCase().contains(_search) ||
                    it.url.toLowerCase().contains(_search);
              }).toList();

              final grouped = _groupByDay(filteredList);

              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: ListView(
                      controller: _vScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!widget.showAppbar) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            child: _buildHeaderBanner(context),
                          ),
                        ],
                        if (filteredList.isEmpty)
                          _buildEmptyState(context)
                        else
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: grouped.entries.map((entry) {
                                    return _buildSection(entry.key, entry.value);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              "No Downloads Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "You haven't downloaded any files yet.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Iconsax.document_download,
                  color: AppColors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Download History",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Every file you've exported or downloaded, in one place",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filter by filename or URL...',
                hintStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
                prefixIcon: const Icon(
                  Iconsax.search_normal_1,
                  size: 16,
                  color: AppColors.grey500,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        splashRadius: 16,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.grey500,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder:OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSearch() {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: 'Filter by filename or URL...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder:OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String label, List<DownloadHistoryModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 16;
            const double minCardWidth = 380;

            final double width = constraints.maxWidth;
            int columns = (width / (minCardWidth + spacing)).floor();
            columns = columns.clamp(1, 3);

            final double itemWidth =
                (width - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _buildDownloadCard(item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDownloadCard(DownloadHistoryModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isSuccess
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.15),
              ),
              child: Icon(
                item.isSuccess ? Icons.check_circle : Icons.error,
                color: item.isSuccess ? AppColors.success : AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.url,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(item.downloadedAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (item.isSuccess)
              Tooltip(
                message: "Open file",
                child: Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openfile(item.filePath, context),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
