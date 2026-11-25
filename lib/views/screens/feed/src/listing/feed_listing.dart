import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:leadcapture/utils/utils.dart' hide timeago;
import 'package:leadcapture/views/views.dart';
import 'package:leadcapture/models/models.dart';
import 'package:leadcapture/constants/constants.dart';
import 'package:leadcapture/services/services.dart';
import 'package:leadcapture/theme/theme.dart';

part 'comment_sheet.dart';

// --- Unified Dashboard Palette ---
class FeedAppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
}

enum FeedTab { all, mine, saved, polls }

extension FeedTabX on FeedTab {
  String get label {
    switch (this) {
      case FeedTab.all:
        return 'All Posts';
      case FeedTab.mine:
        return 'My Posts';
      case FeedTab.saved:
        return 'Saved Posts';
      case FeedTab.polls:
        return 'Polls';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedTab.all:
        return Icons.grid_view_rounded;
      case FeedTab.mine:
        return Icons.person;
      case FeedTab.saved:
        return Icons.bookmark;
      case FeedTab.polls:
        return Icons.bar_chart_rounded;
    }
  }

  String get emptyTitle {
    switch (this) {
      case FeedTab.all:
        return 'No posts yet';
      case FeedTab.mine:
        return "You haven't posted anything yet";
      case FeedTab.saved:
        return 'No saved posts';
      case FeedTab.polls:
        return 'No polls yet';
    }
  }

  String get emptySubtitle {
    switch (this) {
      case FeedTab.all:
        return 'Be the first to share an update with the team.';
      case FeedTab.mine:
        return 'Tap Create Post to share something with the team.';
      case FeedTab.saved:
        return 'Tap the bookmark icon on a post to save it here.';
      case FeedTab.polls:
        return 'Create a post with a poll to see it here.';
    }
  }
}

class _CommentAuthorDisplay {
  final String name;
  final String avatar;

  const _CommentAuthorDisplay({required this.name, required this.avatar});
}

class FeedListing extends StatefulWidget {
  const FeedListing({super.key});

  @override
  State<FeedListing> createState() => _FeedListingState();
}

class _FeedListingState extends State<FeedListing> {
  String? _currentUserUid;
  ScrollController _scrollController = ScrollController();
  FeedTab _tab = FeedTab.all;
  List<FeedModel>? _cachedFeeds;


  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    context.read<FeedBloc>().add(LoadFeeds());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    _currentUserUid = await Spdb.getUid();
    setState(() {});
  }

  void _refreshFeed() {
    context.read<FeedBloc>().add(RefreshFeeds());
  }

  Future<void> _openCreate() async {
    dynamic result;
    if (kIsMobile) {
      result = await Sheet.showSheet(context, widget: const FeedCreate());
    } else {
      result = await GeneralDialog.showRTLSheet(context, const FeedCreate());
    }
    if (result == true && mounted) {
      _refreshFeed();
    }
  }

  List<FeedModel> _applyTab(List<FeedModel> feeds) {
    final uid = _currentUserUid;
    switch (_tab) {
      case FeedTab.all:
        return feeds;
      case FeedTab.mine:
        return feeds.where((f) => uid != null && f.authorId == uid).toList();
      case FeedTab.saved:
        return feeds.where((f) => uid != null && f.savedBy.contains(uid)).toList();
      case FeedTab.polls:
        return feeds.where((f) => f.poll != null).toList();
    }
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dynamic_feed_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stay updated with company announcements, polls, and discussions',
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _refreshFeed,
            icon: const Icon(Iconsax.refresh, size: 16, color: Colors.white),
            label: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add, size: 18, color: Color(0xFF1D4ED8)),
            label: const Text(
              'Create Post',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: FeedTab.values.map((tab) {
                  final selected = tab == _tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _tab = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? FeedAppColors.primary
                              : theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1E3A8A)
                                : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 14,
                              color: selected
                                  ? Colors.white
                                  : FeedAppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : FeedAppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'post' : 'posts'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _tab.icon,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tab.emptyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tab.emptySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Masonry-style layout: cards size to their own content (image, poll,
  /// caption), so they are distributed round-robin into N columns.
  Widget _buildFeedLayout(List<FeedModel> feeds, bool isNarrow) {
    if (isNarrow) {
      return Column(
        children: [
          for (final feed in feeds) ...[
            FeedCard(
              key: ValueKey(feed.uid),
              feed: feed,
              currentUserUid: _currentUserUid,
              onRefresh: _refreshFeed,
              fixedMediaHeight: 280,
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 700 ? 2 : 1);
        final cols = List.generate(columns, (_) => <FeedModel>[]);
        for (var i = 0; i < feeds.length; i++) {
          cols[i % columns].add(feeds[i]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final feed in cols[c]) ...[
                      FeedCard(
                        key: ValueKey(feed.uid),
                        feed: feed,
                        currentUserUid: _currentUserUid,
                        onRefresh: _refreshFeed,
                        fixedMediaHeight: 230,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isNarrow
          ? AppBar(
              leading: Back(color: Theme.of(context).colorScheme.onSurface),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              centerTitle: false,
              title: Text(
                "Community Feed",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _refreshFeed,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.refresh,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                ),
              ),
            )
          : null,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: _openCreate,
        child: const Icon(Iconsax.add, color: Colors.white),
        ),
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoaded) _cachedFeeds = state.feeds;
          if (state is FeedError) return ErrorDisplay(error: state.message);

          final allFeeds = _cachedFeeds;
          if (allFeeds == null) {
            if (state is FeedLoading || state is FeedInitial) {
              return const Center(child: WaitingLoading());
            }
            return const SizedBox.shrink();
          }

          final feeds = _applyTab(allFeeds);

          return RefreshIndicator(
            onRefresh: () async => _refreshFeed(),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              trackVisibility: true,
              radius: const Radius.circular(8),
              thickness: 8,
              child: ScrollConfiguration(
                // The app shell already draws its own scrollbar; disable the
                // automatic one so two scrollbars don't appear side by side.
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 20,
                    isNarrow ? 12 : 20,
                    isNarrow ? 12 : 20,
                    90,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isNarrow) ...[
                            _buildBanner(context),
                            const SizedBox(height: 16),
                          ],
                          _buildTabsBar(context, feeds.length),
                          const SizedBox(height: 16),
                          if (feeds.isEmpty)
                            _buildEmpty(context)
                          else
                            _buildFeedLayout(feeds, isNarrow),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wraps the media section with either `Expanded` (grid/multi-column mode,
/// where the parent always gives a bounded height via a fixed aspect
/// ratio) or a fixed-height `SizedBox` (single-column list mode, where the
/// parent gives unbounded height - `Expanded` there would crash Flutter's
/// layout with "incoming height constraints are unbounded").
class _MediaSectionWrapper extends StatelessWidget {
  final double? fixedHeight;
  final Widget child;

  const _MediaSectionWrapper({required this.fixedHeight, required this.child});

  @override
  Widget build(BuildContext context) {
    if (fixedHeight != null) {
      return SizedBox(height: fixedHeight, child: child);
    }
    return Expanded(child: child);
  }
}

class FeedCard extends StatefulWidget {
  final FeedModel feed;
  final String? currentUserUid;
  final VoidCallback onRefresh;
  // When null (grid/multi-column usage), the media section uses Expanded
  // to fill whatever height the grid's fixed aspect ratio gives it. When
  // set (single-column list usage, where the parent gives each item
  // unbounded height), Expanded would crash - so a fixed intrinsic height
  // is used instead.
  final double? fixedMediaHeight;

  const FeedCard({
    super.key,
    required this.feed,
    this.currentUserUid,
    required this.onRefresh,
    this.fixedMediaHeight,
  });

  @override
  State<FeedCard> createState() => FeedCardState();
}

class FeedCardState extends State<FeedCard> {
  int _currentImageIndex = 0;
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;
  late String _postAuthorName;
  late String _postAuthorAvatar;
  bool _isAdmin = false;
  bool _isVoting = false;
    ScrollController viewpostscrollController = ScrollController();

  Future<void> _checkAdmin() async {
    final isAdmin = await Spdb.isAdminLoggedIn();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    viewpostscrollController.dispose();
    super.dispose();
  }

  int get _commentCount {
    final localCount = widget.feed.comments?.length ?? 0;
    if (localCount > 0) return localCount;
    return widget.feed.commentsCount;
  }

  Future<_CommentAuthorDisplay?> _loadCommentAuthorDisplay(String uid) async {
    // This only ever checked the Admin cache/service, so any post or
    // comment authored by an Employee (not present in the Admin
    // collection) fell through to the 'Unknown user' placeholder even
    // though the employee's profile does exist. Check the employee cache
    // and service too, matching the adminByUid/employeeByUid pattern
    // already used elsewhere (see pinned_messages_bar.dart).
    final cachedEmployee = CacheService.employeeByUid(uid);
    if (cachedEmployee != null) {
      return _CommentAuthorDisplay(
        name: cachedEmployee.name,
        avatar: cachedEmployee.profileImageUrl ?? '',
      );
    }

    final cachedAdmin = CacheService.adminByUid(uid);
    if (cachedAdmin != null) {
      return _CommentAuthorDisplay(
        name: cachedAdmin.name,
        avatar: cachedAdmin.profileImageUrl ?? '',
      );
    }

    final employee = await EmployeeService.getEmployee(uid: uid);
    if (employee != null) {
      return _CommentAuthorDisplay(
        name: employee.name,
        avatar: employee.profileImageUrl ?? '',
      );
    }

    final admin = await AdminService.getAdmin(uid: uid);
    if (admin != null) {
      return _CommentAuthorDisplay(
        name: admin.name,
        avatar: admin.profileImageUrl ?? '',
      );
    }

    return const _CommentAuthorDisplay(name: 'Unknown user', avatar: '');
  }

  Future<void> _loadPostAuthorDisplay() async {
    final display = await _loadCommentAuthorDisplay(widget.feed.authorId);
    if (!mounted || display == null) return;

    setState(() {
      _postAuthorName = display.name;
      _postAuthorAvatar = display.avatar;
    });
  }

  Future<Map<String, _CommentAuthorDisplay>> _loadCommentAuthors(
    List<CommentModel> comments,
  ) async {
    final result = <String, _CommentAuthorDisplay>{};
    final ids = comments
        .map((c) => c.authorId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    for (final id in ids) {
      final display = await _loadCommentAuthorDisplay(id);
      if (display != null) {
        result[id] = display;
      }
    }

    return result;
  }

  Future<void> _openUserProfileFromComment(String uid) async {
    if (uid.trim().isEmpty) return;

    final admin = await AdminService.getAdmin(uid: uid);
    if (admin != null) {
      if (!mounted) return;
      if (kIsMobile) {
        await Sheet.showSheet(context, widget: AdminProfile(admin: admin));
      } else {
        await GeneralDialog.showRTLSheet(context, AdminProfile(admin: admin));
      }
      return;
    }

    if (!mounted) return;
    FlushBar.show(context, 'User profile not found', isSuccess: false);
  }

  Future<void> _openPostPreview({int initialImageIndex = 0}) async {
    final imageCount = widget.feed.mediaImages.length;
    final startIndex = imageCount == 0
        ? 0
        : initialImageIndex.clamp(0, imageCount - 1);

    String postAuthorName = widget.feed.authorName;
    String postAuthorAvatar = widget.feed.authorAvatar;
    Map<String, _CommentAuthorDisplay> commentAuthors = {};

    try {
      final postAuthorDisplay = await _loadCommentAuthorDisplay(
        widget.feed.authorId,
      );
      if (!mounted) return;
      postAuthorName = postAuthorDisplay?.name ?? widget.feed.authorName;
      postAuthorAvatar = postAuthorDisplay?.avatar ?? widget.feed.authorAvatar;
    } catch (_) {}

    final pollModel = widget.feed.poll == null
        ? null
        : PollModel(
            pollId: widget.feed.poll!.pollId,
            question: widget.feed.poll!.question,
            options: widget.feed.poll!.options
                .map(
                  (o) => PollOption(
                    optionId: o.optionId,
                    title: o.title,
                    votes: o.votes,
                  ),
                )
                .toList(),
            votedUserIds: List<String>.from(widget.feed.poll!.votedUserIds),
          );

    String? selectedOptionId;
    bool isVoting = false;
    int dialogImageIndex = startIndex;
    final List<CommentModel> dialogComments = List<CommentModel>.from(
      widget.feed.comments ?? const <CommentModel>[],
    );

    try {
      commentAuthors = await _loadCommentAuthors(dialogComments);
      if (!mounted) return;
    } catch (_) {}

    final TextEditingController dialogCommentController =
        TextEditingController();
    bool isPostingComment = false;
    final PageController dialogPageController = PageController(
      initialPage: startIndex,
    );

    if (!mounted) return;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final totalVotes = pollModel == null
                  ? 0
                  : pollModel.options.fold<int>(
                      0,
                      (sum, option) => sum + option.votes,
                    );
              final hasCurrentUserVoted =
                  widget.currentUserUid != null &&
                  pollModel != null &&
                  pollModel.votedUserIds.contains(widget.currentUserUid);

              final Color accent = _accentColorForName(postAuthorName);
              final double screenWidth = MediaQuery.of(context).size.width;
              final double screenHeight = MediaQuery.of(context).size.height;
              final bool isNarrowDialog = screenWidth < 700;
              // Image area scales with the viewport instead of a fixed
              // 420px, which wasted a lot of space as black bars when an
              // image's aspect ratio didn't match the fixed box.
              final double imageAreaHeight = (screenHeight * 0.42).clamp(
                260.0,
                460.0,
              );

              // Wide screens: image on the left (dark panel), details on the
              // right - mirrors the reference design. Narrow: stacked layout.
              final bool useSplit =
                  !isNarrowDialog &&
                  screenWidth >= 900 &&
                  widget.feed.mediaImages.isNotEmpty;
              final double splitHeight = (screenHeight - 48).clamp(
                420.0,
                600.0,
              );

              Widget buildImagePager(double? height) => SizedBox(
                              height: height,
                              child: Stack(
                                children: [
                                  PageView.builder(
                                    controller: dialogPageController,
                                    itemCount: widget.feed.mediaImages.length,
                                    onPageChanged: (index) {
                                      setDialogState(() {
                                        dialogImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color.lerp(
                                                Colors.black,
                                                accent,
                                                0.25,
                                              )!,
                                              Colors.black,
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Image.network(
                                            widget.feed.mediaImages[index].url,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (widget.feed.mediaImages.length > 1)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 10,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(
                                                14,
                                              ),
                                            ),
                                            child: Text(
                                              'Swipe to see all images',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(
                                                14,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(
                                                widget.feed.mediaImages.length,
                                                (idx) => Container(
                                                  width: 6,
                                                  height: 6,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: dialogImageIndex == idx
                                                        ? Colors.white
                                                        : Colors.white54,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (widget.feed.mediaImages.length > 1)
                                    Positioned(
                                      left: 6,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        onPressed: dialogImageIndex == 0
                                            ? null
                                            : () {
                                                dialogPageController.previousPage(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),
                                                  curve: Curves.easeOut,
                                                );
                                              },
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  if (widget.feed.mediaImages.length > 1)
                                    Positioned(
                                      right: 6,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        onPressed:
                                            dialogImageIndex ==
                                                widget.feed.mediaImages.length - 1
                                            ? null
                                            : () {
                                                dialogPageController.nextPage(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),
                                                  curve: Curves.easeOut,
                                                );
                                              },
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );

              Widget wrapSplit(Widget rightColumn) {
                if (!useSplit) return rightColumn;
                return SizedBox(
                  height: splitHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20),
                          ),
                          child: Container(
                            color: const Color(0xFF0B1220),
                            child: buildImagePager(double.infinity),
                          ),
                        ),
                      ),
                      SizedBox(width: 400, child: rightColumn),
                    ],
                  ),
                );
              }

              return Dialog(
                insetPadding: isNarrowDialog
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isNarrowDialog
                        ? double.infinity
                        : (useSplit ? 1000 : 820),
                    maxHeight: isNarrowDialog ? double.infinity : 900,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: isNarrowDialog
                          ? BorderRadius.zero
                          : BorderRadius.circular(20),
                    ),
                    child: wrapSplit(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                          child: Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openUserProfileFromComment(
                                  widget.feed.authorId,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    backgroundImage: NetworkImage(
                                      postAuthorAvatar.isNotEmpty
                                          ? postAuthorAvatar
                                          : AppStrings.emptyProfilePhotoUrl,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => _openUserProfileFromComment(
                                        widget.feed.authorId,
                                      ),
                                      child: Text(
                                        postAuthorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _buildTimeLabel(widget.feed),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => Navigator.pop(dialogContext),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        
                        // Text, Poll and Comments section
                        Expanded(
                          child: Scrollbar(
                    controller: viewpostscrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                            child: SingleChildScrollView(
                              controller: viewpostscrollController,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Images section (stacked layout only)
                                  if (widget.feed.mediaImages.isNotEmpty && !useSplit)
                                    buildImagePager(imageAreaHeight),
                            SizedBox(height: 10),
                                  if (widget.feed.content.trim().isNotEmpty) ...[
                                    SelectableText(
                                      widget.feed.content,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                                
                                  if (pollModel != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.bar_chart_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  pollModel.question,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ...pollModel.options.map((option) {
                                            final isSelected =
                                                selectedOptionId == option.optionId;
                                            final pct = totalVotes == 0
                                                ? 0
                                                : ((option.votes / totalVotes) *
                                                          100)
                                                      .round();
                                                
                                            return GestureDetector(
                                              onTap: hasCurrentUserVoted
                                                  ? null
                                                  : () {
                                                      setDialogState(() {
                                                        selectedOptionId =
                                                            option.optionId;
                                                      });
                                                    },
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? accent
                                                        : Theme.of(
                                                            context,
                                                          ).colorScheme.outlineVariant,
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    if (totalVotes > 0)
                                                      Positioned.fill(
                                                        child: FractionallySizedBox(
                                                          alignment:
                                                              Alignment.centerLeft,
                                                          widthFactor: pct / 100,
                                                          child: Container(
                                                            color: accent
                                                                .withValues(
                                                                  alpha: 0.14,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 9,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          if (isSelected) ...[
                                                            Icon(
                                                              Icons.check_circle,
                                                              size: 15,
                                                              color: accent,
                                                            ),
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                          ],
                                                          Expanded(
                                                            child: Text(
                                                              option.title,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            '${option.votes} votes${totalVotes > 0 ? ' ($pct%)' : ''}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: accent,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              if (widget.currentUserUid != null)
                                                ElevatedButton(
                                                  onPressed:
                                                      (selectedOptionId == null ||
                                                          hasCurrentUserVoted ||
                                                          isVoting)
                                                      ? null
                                                      : () async {
                                                          final feedId =
                                                              widget.feed.uid;
                                                          if (feedId == null) {
                                                            FlushBar.show(
                                                              context,
                                                              'Feed id is missing',
                                                              isSuccess: false,
                                                            );
                                                            return;
                                                          }
                                                
                                                          setDialogState(() {
                                                            isVoting = true;
                                                          });
                                                
                                                          try {
                                                            await FeedService.votePoll(
                                                              feedId: feedId,
                                                              optionId:
                                                                  selectedOptionId!,
                                                            );
                                                
                                                            setDialogState(() {
                                                              final option = pollModel
                                                                  .options
                                                                  .firstWhere(
                                                                    (o) =>
                                                                        o.optionId ==
                                                                        selectedOptionId,
                                                                  );
                                                              option.votes += 1;
                                                              if (widget
                                                                      .currentUserUid !=
                                                                  null) {
                                                                pollModel
                                                                    .votedUserIds
                                                                    .add(
                                                                      widget
                                                                          .currentUserUid!,
                                                                    );
                                                              }
                                                              isVoting = false;
                                                            });
                                                
                                                            if (mounted) {
                                                              widget.onRefresh();
                                                            }
                                                          } catch (e) {
                                                            setDialogState(() {
                                                              isVoting = false;
                                                            });
                                                            if (mounted) {
                                                              FlushBar.show(
                                                                context,
                                                                e.toString(),
                                                                isSuccess: false,
                                                              );
                                                            }
                                                          }
                                                        },
                                                  child: Text(
                                                    hasCurrentUserVoted
                                                        ? 'Already Participated'
                                                        : isVoting
                                                        ? 'Voting...'
                                                        : 'Participate',
                                                  ),
                                                ),
                                              if (widget.currentUserUid ==
                                                  widget.feed.authorId)
                                                OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.pop(dialogContext);
                                                    _openPostEdit();
                                                  },
                                                  child: const Text('Manage Poll'),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                                
                                  if (widget.feed.attachments.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Iconsax.folder_open,
                                          size: 15,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Attachments (${widget.feed.attachments.length})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        primary: false,
                                        padding: const EdgeInsets.all(10),
                                        itemCount: widget.feed.attachments.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 14),
                                        itemBuilder: (context, index) {
                                          final file =
                                              widget.feed.attachments[index];
                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: accent.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Iconsax.document,
                                                  size: 14,
                                                  color: accent,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      file.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: FeedAppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatFileSize(file.size),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: FeedAppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    previewAttachment(
                                                      context,
                                                      file,
                                                    ),
                                                child: const Text('Open'),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                                
                                 
                                  const SizedBox(height: 8),
                                                
                                  Row(
                                    children: [
                                      Icon(
                                        Iconsax.message_text,
                                        size: 15,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Comments (${dialogComments.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 300,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: dialogComments.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No comments yet',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          : Scrollbar(
                                              thumbVisibility: true,
                                              child: ListView.separated(
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(),
                                                primary: false,
                                                padding: const EdgeInsets.all(10),
                                                itemCount: dialogComments.length,
                                                separatorBuilder:
                                                    (context, index) =>
                                                        const SizedBox(height: 10),
                                                itemBuilder: (context, index) {
                                                  final comment =
                                                      dialogComments[index];
                                                  final liveAuthor =
                                                      commentAuthors[comment
                                                          .authorId];
                                                  final authorName =
                                                      liveAuthor?.name ??
                                                      comment.authorName;
                                                  final authorAvatar =
                                                      liveAuthor?.avatar ??
                                                      comment.authorAvatar;
                                                  final canDelete = _isAdmin ||
                                                      widget.currentUserUid ==
                                                      comment.authorId;
                                                
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          InkWell(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            onTap: () =>
                                                                _openUserProfileFromComment(
                                                                  comment.authorId,
                                                                ),
                                                            child: CircleAvatar(
                                                              radius: 12,
                                                              backgroundColor:
                                                                  FeedAppColors
                                                                      .background,
                                                              backgroundImage: NetworkImage(
                                                                authorAvatar
                                                                        .isNotEmpty
                                                                    ? authorAvatar
                                                                    : AppStrings
                                                                          .emptyProfilePhotoUrl,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                InkWell(
                                                                  onTap: () =>
                                                                      _openUserProfileFromComment(
                                                                        comment
                                                                            .authorId,
                                                                      ),
                                                                  child: Text(
                                                                    authorName,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize: 11,
                                                                      color: FeedAppColors
                                                                          .textPrimary,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Text(
                                                                  timeago.format(
                                                                    comment
                                                                        .createdAt,
                                                                    locale:
                                                                        'en_short',
                                                                  ),
                                                                  style: const TextStyle(
                                                                    fontSize: 9,
                                                                    color: FeedAppColors
                                                                        .textSecondary,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (canDelete)
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color: Colors.red,
                                                              ),
                                                              onPressed: () async {
                                                                final shouldDelete = await showDialog<bool>(
                                                                  context: context,
                                                                  builder: (confirmContext) {
                                                                    return AlertDialog(
                                                                      title: const Text(
                                                                        'Delete Comment',
                                                                      ),
                                                                      content:
                                                                          const Text(
                                                                            'Are you sure you want to delete this comment?',
                                                                          ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () =>
                                                                              Navigator.pop(
                                                                                confirmContext,
                                                                                false,
                                                                              ),
                                                                          child: const Text(
                                                                            'Cancel',
                                                                          ),
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () =>
                                                                              Navigator.pop(
                                                                                confirmContext,
                                                                                true,
                                                                              ),
                                                                          child: const Text(
                                                                            'Delete',
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                );
                                                
                                                                if (shouldDelete !=
                                                                    true) {
                                                                  return;
                                                                }
                                                
                                                                try {
                                                                  await FeedService.deleteComment(
                                                                    feedId:
                                                                        widget
                                                                            .feed
                                                                            .uid ??
                                                                        '',
                                                                    commentId: comment
                                                                        .commentId,
                                                                  );
                                                
                                                                  setDialogState(() {
                                                                    dialogComments
                                                                        .removeWhere(
                                                                          (c) =>
                                                                              c.commentId ==
                                                                              comment
                                                                                  .commentId,
                                                                        );
                                                                  });
                                                
                                                                  if (mounted) {
                                                                    widget
                                                                        .onRefresh();
                                                                  }
                                                                } catch (e) {
                                                                  if (mounted) {
                                                                    FlushBar.show(
                                                                      context,
                                                                      e.toString(),
                                                                      isSuccess:
                                                                          false,
                                                                    );
                                                                  }
                                                                }
                                                              },
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        comment.content,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          height: 1.3,
                                                          color: FeedAppColors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: dialogCommentController,
                                          minLines: 1,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText: 'Add a comment...',
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(
                                                10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: isPostingComment
                                            ? null
                                            : () async {
                                                final feedId = widget.feed.uid;
                                                final uid = widget.currentUserUid;
                                                final content =
                                                    dialogCommentController.text
                                                        .trim();
                                                
                                                if (feedId == null ||
                                                    feedId.isEmpty) {
                                                  FlushBar.show(
                                                    context,
                                                    'Feed id is missing',
                                                    isSuccess: false,
                                                  );
                                                  return;
                                                }
                                                
                                                if (uid == null || uid.isEmpty) {
                                                  FlushBar.show(
                                                    context,
                                                    'User not found',
                                                    isSuccess: false,
                                                  );
                                                  return;
                                                }
                                                
                                                if (content.isEmpty) {
                                                  return;
                                                }
                                                
                                                setDialogState(() {
                                                  isPostingComment = true;
                                                });
                                                
                                                try {
                                                  String authorName = 'Anonymous';
                                                  String authorAvatar = '';
                                                
                                                  final isAdmin =
                                                      await Spdb.isAdminLoggedIn();
                                                  if (isAdmin) {
                                                    final admin =
                                                        await AdminService.getAdmin(
                                                          uid: uid,
                                                        );
                                                    authorName =
                                                        admin?.name ?? 'Anonymous';
                                                    authorAvatar =
                                                        admin?.profileImageUrl ??
                                                        '';
                                                  } else {
                                                    // Bug fix: this previously
                                                    // called AdminService.getAdmin
                                                    // here too, so an employee's
                                                    // uid (not present in the
                                                    // Admin collection) always
                                                    // resolved to null, making
                                                    // every employee comment show
                                                    // as "Anonymous".
                                                    final employee =
                                                        await EmployeeService
                                                            .getEmployee(
                                                          uid: uid,
                                                        );
                                                    authorName =
                                                        employee?.name ??
                                                        'Anonymous';
                                                    authorAvatar =
                                                        employee?.profileImageUrl ??
                                                        '';
                                                  }
                                                
                                                  final newComment = CommentModel(
                                                    commentId: DateTime.now()
                                                        .millisecondsSinceEpoch
                                                        .toString(),
                                                    authorId: uid,
                                                    authorName: authorName,
                                                    authorAvatar: authorAvatar,
                                                    content: content,
                                                    createdAt: DateTime.now(),
                                                  );
                                                
                                                  final savedComment = await FeedService.addComment(
                                                    feedId: feedId,
                                                    comment: newComment,
                                                  );
                                                
                                                  setDialogState(() {
                                                    commentAuthors[uid] =
                                                        _CommentAuthorDisplay(
                                                          name: authorName,
                                                          avatar: authorAvatar,
                                                        );
                                                    dialogComments.insert(
                                                      0,
                                                      savedComment ??
                                                          newComment,
                                                    );
                                                    dialogCommentController.clear();
                                                    isPostingComment = false;
                                                  });
                                                
                                                  if (mounted) {
                                                    widget.onRefresh();
                                                  }
                                                } catch (e) {
                                                  setDialogState(() {
                                                    isPostingComment = false;
                                                  });
                                                  if (mounted) {
                                                    FlushBar.show(
                                                      context,
                                                      e.toString(),
                                                      isSuccess: false,
                                                    );
                                                  }
                                                }
                                              },
                                        child: Text(
                                          isPostingComment ? 'Posting...' : 'Post',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      dialogCommentController.dispose();
      dialogPageController.dispose();
    }
  }

  Future<void> _showPostSavedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Post saved successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPostDeletedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Post deleted successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDeletePost() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _openPostEdit() async {
    if (kIsMobile) {
      final result = await Sheet.showSheet(
        context,
        widget: FeedEdit(uid: widget.feed.uid ?? ''),
      );
      if (result == true && mounted) {
        widget.onRefresh();
        await _showPostSavedDialog();
      }
    } else {
      final result = await GeneralDialog.showRTLSheet(
        context,
        FeedEdit(uid: widget.feed.uid ?? ''),
      );
      if (result == true && mounted) {
        widget.onRefresh();
        await _showPostSavedDialog();
      }
    }
  }

  Future<void> _deletePost() async {
    final shouldDelete = await _confirmDeletePost();
    if (!shouldDelete) return;

    try {
      futureLoading(context);
      await FeedService.deleteFeed(uid: widget.feed.uid ?? '');

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      widget.onRefresh();
      await _showPostDeletedDialog();
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _postAuthorName = widget.feed.authorName;
    _postAuthorAvatar = widget.feed.authorAvatar;
    _loadPostAuthorDisplay();
    _isLiked = widget.feed.reactions.any(
      (r) => r.userId == widget.currentUserUid,
    );
    _isSaved =
        widget.currentUserUid != null &&
        widget.feed.savedBy.contains(widget.currentUserUid);
    _likeCount = widget.feed.reactions.length;
  }

  @override
  void didUpdateWidget(covariant FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isVoting &&
        widget.currentUserUid != null &&
        (widget.feed.poll?.votedUserIds.contains(widget.currentUserUid) ??
            false)) {
      _isVoting = false;
    }
    if (oldWidget.feed.authorId != widget.feed.authorId ||
        oldWidget.feed.authorName != widget.feed.authorName ||
        oldWidget.feed.authorAvatar != widget.feed.authorAvatar) {
      _postAuthorName = widget.feed.authorName;
      _postAuthorAvatar = widget.feed.authorAvatar;
      _loadPostAuthorDisplay();
    }
  }

  void _handleLike() {
    if (widget.currentUserUid == null) return;
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });
    context.read<FeedBloc>().add(
      ToggleLike(feedId: widget.feed.uid!, userId: widget.currentUserUid!),
    );
  }

  void _handleSave() {
    if (widget.currentUserUid == null) return;
    setState(() {
      _isSaved = !_isSaved;
    });
    context.read<FeedBloc>().add(
      ToggleSaveFeed(feedId: widget.feed.uid!, userId: widget.currentUserUid!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;
    final Color accent = _accentColorForName(_postAuthorName);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        children: [
          // Colorful accent spine - gives every author's posts a distinct,
          // vibrant identity instead of a flat uniform white card top.
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Header - Condensed
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      _openUserProfileFromComment(widget.feed.authorId),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      backgroundImage: NetworkImage(
                        _postAuthorAvatar.isNotEmpty
                            ? _postAuthorAvatar
                            : AppStrings.emptyProfilePhotoUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () =>
                            _openUserProfileFromComment(widget.feed.authorId),
                        child: Text(
                          _postAuthorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _buildTimeLabel(widget.feed),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bug fix: this previously showed the "..." edit/delete menu
                // for any admin on every post, regardless of who actually
                // created it. Tapping "Delete Post" on someone else's post
                // then failed server-side with "Only post creator can delete
                // this post" — a confusing dead-end instead of the option
                // simply not being there. Only the post's own creator should
                // see this menu at all.
                if (widget.currentUserUid != null &&
                    widget.currentUserUid == widget.feed.authorId)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Iconsax.more,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _openPostEdit();
                        return;
                      }

                      if (value == 'delete') {
                        await _deletePost();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.edit_2,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            const Text('Edit Post'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Iconsax.trash, size: 16, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Delete Post',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Media Section - only when the post has images or attachments
          if (widget.feed.mediaImages.isNotEmpty ||
              widget.feed.attachments.isNotEmpty)
          _MediaSectionWrapper(
            fixedHeight: widget.fixedMediaHeight,
            child: InkWell(
              onTap: () =>
                  _openPostPreview(initialImageIndex: _currentImageIndex),
              child: Stack(
                children: [
                  if (widget.feed.mediaImages.isNotEmpty)
                    CarouselSlider(
                      options: CarouselOptions(
                        height: double.infinity,
                        viewportFraction: 1,
                        enableInfiniteScroll: false,
                        onPageChanged: (index, _) =>
                            setState(() => _currentImageIndex = index),
                      ),
                      items: widget.feed.mediaImages
                          .map(
                            (m) => Image.network(
                              m.url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                          .toList(),
                    )
                  else if (widget.feed.attachments.isNotEmpty)
                    _buildAttachmentsPreview()
                  else if (widget.feed.content.isNotEmpty)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.14),
                            accent.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: Text(
                        widget.feed.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Iconsax.document_text,
                        color: Theme.of(context).dividerColor,
                        size: 40,
                      ),
                    ),

                  // Pagination Indicator Overlay
                  if (widget.feed.mediaImages.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.feed.mediaImages.length,
                          (index) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Lower Content area
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.feed.content.isNotEmpty)
                  Text(
                    widget.feed.content,
                    maxLines: (widget.feed.mediaImages.isNotEmpty ||
                            widget.feed.attachments.isNotEmpty)
                        ? 2
                        : 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (widget.feed.content.length > 120)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: _openPostPreview,
                      child: Text(
                        'View full post',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                if (widget.feed.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.attach_circle,
                            size: 12,
                            color: accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.feed.attachments.length} file${widget.feed.attachments.length == 1 ? '' : 's'} attached',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.feed.poll != null) ...[
                  const SizedBox(height: 8),
                  _buildInlinePoll(theme),
                ],
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
                const SizedBox(height: 4),

                // Interaction Bar
                Row(
                  children: [
                    _interactionIcon(
                      _isLiked ? Iconsax.heart5 : Iconsax.heart,
                      _isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      _likeCount > 0 ? _likeCount.toString() : "",
                      _handleLike,
                    ),
                    const SizedBox(width: 14),
                    _interactionIcon(
                      Iconsax.message,
                      theme.colorScheme.onSurfaceVariant,
                      _commentCount > 0 ? _commentCount.toString() : "",
                      () => _showCommentSheet(),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _handleSave,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 20,
                            color: _isSaved
                                ? FeedAppColors.primary
                                : FeedAppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _handleVote(String optionId) {
    if (widget.currentUserUid == null || _isVoting) return;
    final feedId = widget.feed.uid;
    if (feedId == null) return;
    setState(() => _isVoting = true);
    context.read<FeedBloc>().add(VotePoll(feedId: feedId, optionId: optionId));
    // The bloc re-fetches feeds after a vote; release the guard either way.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isVoting = false);
    });
  }

  Widget _buildInlinePoll(ThemeData theme) {
    final poll = widget.feed.poll!;
    const Color pollAccent = Color(0xFFF59E0B);
    final int totalVotes = poll.options.fold<int>(0, (sum, o) => sum + o.votes);
    final int maxVotes = poll.options.fold<int>(
      0,
      (m, o) => o.votes > m ? o.votes : m,
    );
    final bool hasVoted =
        widget.currentUserUid != null &&
        poll.votedUserIds.contains(widget.currentUserUid);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pollAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 14, color: pollAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...poll.options.map((option) {
            final int pct = totalVotes == 0
                ? 0
                : ((option.votes / totalVotes) * 100).round();
            final bool isLeading = maxVotes > 0 && option.votes == maxVotes;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: hasVoted || widget.currentUserUid == null
                    ? null
                    : () => _handleVote(option.optionId),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.light
                        ? Colors.white
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Stack(
                    children: [
                      if (totalVotes > 0 && isLeading)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (pct / 100).clamp(0.0, 1.0),
                            child: Container(
                              color: pollAccent.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Row(
            children: [
              Text(
                '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (hasVoted)
                const Text(
                  '✓ Already Participated',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                )
              else if (_isVoting)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  'Tap an option to vote',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsPreview() {
    final attachments = widget.feed.attachments;
    final theme = Theme.of(context);
    final Color accent = _accentColorForName(_postAuthorName);
    final bool isSingle = attachments.length == 1;

    // Fixed-height summary instead of listing every file: a file list that
    // grows with attachment count previously overflowed the card's media
    // area on narrow (mobile grid) cells, since that area has a fixed
    // height driven by the grid's aspect ratio.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.04),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSingle ? Iconsax.document_text_1 : Iconsax.folder_open,
              size: 26,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSingle ? attachments.first.name : '${attachments.length} files',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (isSingle) ...[
            const SizedBox(height: 2),
            Text(
              _formatFileSize(attachments.first.size),
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _interactionIcon(
    IconData icon,
    Color color,
    String count,
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (count.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Deterministic vibrant accent color per author name, used for the
  /// card's top spine and avatar ring so the feed reads as colorful and
  /// each author's posts feel visually distinct - purely presentational,
  /// same author always gets the same color.
  static const List<Color> _accentPalette = [
    Color(0xFF4364F7), // blue
    Color(0xFF10B981), // green
    Color(0xFFF97316), // orange
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF06B6D4), // cyan
    Color(0xFFEF4444), // red
    Color(0xFFF59E0B), // amber
  ];

  Color _accentColorForName(String name) {
    if (name.isEmpty) return _accentPalette.first;
    final int hash = name.codeUnits.fold(0, (a, b) => a + b);
    return _accentPalette[hash % _accentPalette.length];
  }

  String _formatShortTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _buildTimeLabel(FeedModel feed) {
    final created = feed.createdAt.toLocal();
    final createdLabel = '${_months[created.month - 1]} ${created.day}';
    final updatedAt = feed.updatedAt;

    if (updatedAt == null || updatedAt.isAtSameMomentAs(feed.createdAt)) {
      return 'Posted $createdLabel';
    }

    return 'Posted $createdLabel · Edited ${_formatShortTime(updatedAt)} ago';
  }

  Future<void> _showCommentSheet() async {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (!kIsMobile && screenWidth >= 700) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Comments',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, _, __) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Theme.of(dialogContext).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 480,
                height: MediaQuery.of(dialogContext).size.height,
                child: CommentSheet(
                  feedId: widget.feed.uid!,
                  currentUserUid: widget.currentUserUid,
                  initialComments: widget.feed.comments ?? [],
                  asSidePanel: true,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );

      if (mounted) {
        widget.onRefresh();
      }
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => CommentSheet(
        feedId: widget.feed.uid!,
        currentUserUid: widget.currentUserUid,
        initialComments: widget.feed.comments ?? [],
      ),
    );

    if (mounted) {
      widget.onRefresh();
    }
  }
}