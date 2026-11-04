part of 'feed_listing.dart';

class CommentSheet extends StatefulWidget {
  final String feedId;
  final String? currentUserUid;
  final List<CommentModel> initialComments;

  const CommentSheet({
    super.key,
    required this.feedId,
    this.currentUserUid,
    required this.initialComments,
  });

  @override
  State<CommentSheet> createState() => CommentSheetState();
}

class CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();
  late List<CommentModel> _comments;
  late Future _future;
  final Map<String, _CommentAuthorDisplay> _commentAuthors = {};
  EmployeeModel? _employee;
  AdminModel? _admin;
  bool _isPosting = false;
  CommentModel? _replyingTo;
  bool _isAdmin = false;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  void _setReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
    });
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _init() async {
    if (widget.currentUserUid == null) return;
    _isAdmin = await Spdb.isAdminLoggedIn();
    if (_isAdmin) {
      _admin = await AdminService.getAdmin(uid: widget.currentUserUid!);
    } else {
      _employee = await EmployeeService.getEmployee(
        uid: widget.currentUserUid!,
      );
    }
    var feedModel = await FeedService.getFeed(uid: widget.feedId);
    _comments = feedModel.comments ?? [];
    _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _loadCommentAuthors();
  }

  Future<void> _loadCommentAuthors() async {
    final ids = _comments
        .map((c) => c.authorId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    for (final id in ids) {
      final display = await _loadCommentAuthorDisplay(id);
      if (display != null) {
        _commentAuthors[id] = display;
      }
    }
  }

  Future<_CommentAuthorDisplay?> _loadCommentAuthorDisplay(String uid) async {
    final cachedUser = CacheService.getUserByUid(uid);
    if (cachedUser is EmployeeModel) {
      return _CommentAuthorDisplay(
        name: cachedUser.name,
        avatar: cachedUser.profileImageUrl ?? '',
      );
    }

    if (cachedUser is AdminModel) {
      return _CommentAuthorDisplay(
        name: cachedUser.name,
        avatar: cachedUser.profileImageUrl ?? '',
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

  Future<void> _openCommentAuthorProfile(String uid) async {
    if (uid.trim().isEmpty) return;

    final employee = await EmployeeService.getEmployee(uid: uid);
    if (employee != null) {
      if (!mounted) return;
      if (kIsMobile) {
        await Sheet.showSheet(
          context,
          widget: EmployeeDetails(employee: employee),
        );
      } else {
        await GeneralDialog.showRTLSheet(
          context,
          EmployeeDetails(employee: employee),
        );
      }
      return;
    }

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

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty ||
        widget.currentUserUid == null) {
      return;
    }
    final content = _commentController.text.trim();
    _commentController.clear();
    setState(() => _isPosting = true);

    try {
      final String authorName = _admin?.name ?? _employee?.name ?? 'Anonymous';
      final String authorAvatar =
          _admin?.profileImageUrl ?? _employee?.profileImageUrl ?? '';

      final newComment = CommentModel(
        commentId: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: widget.currentUserUid!,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        replyToCommentId: _replyingTo?.commentId,
        createdAt: DateTime.now(),
      );

      await FeedService.addComment(feedId: widget.feedId, comment: newComment);
      setState(() {
        _commentAuthors[widget.currentUserUid!] = _CommentAuthorDisplay(
          name: authorName,
          avatar: authorAvatar,
        );
        _comments.insert(0, newComment);
        _isPosting = false;
        _replyingTo = null;
      });
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) {
        FlushBar.show(context, "Failed to post comment", isSuccess: false);
      }
    }
  }

  Future<void> _toggleReaction(CommentModel comment, String emoji) async {
    final uid = widget.currentUserUid!;
    final reactions = Map<String, List<String>>.from(comment.reactions);

    final users = reactions[emoji] ?? [];

    if (users.contains(uid)) {
      users.remove(uid);
    } else {
      users.add(uid);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    final updated = comment.copyWith(reactions: reactions);

    setState(() {
      final index = _comments.indexWhere(
        (c) => c.commentId == comment.commentId,
      );
      _comments[index] = updated;
    });

    await FeedService.updateCommentReaction(
      feedId: widget.feedId,
      commentId: comment.commentId,
      reactions: reactions,
    );
  }

  Future<void> _editComment(CommentModel comment) async {
    if (widget.currentUserUid == null ||
        comment.authorId != widget.currentUserUid) {
      return;
    }

    _editCommentController.text = comment.content;

    final updatedContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            controller: _editCommentController,
            minLines: 1,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Update your comment'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _editCommentController.text.trim(),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updatedContent == null || updatedContent.isEmpty) return;

    try {
      await FeedService.editComment(
        feedId: widget.feedId,
        commentId: comment.commentId,
        content: updatedContent,
      );

      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere(
          (c) => c.commentId == comment.commentId,
        );
        if (index != -1) {
          _comments[index] = _comments[index].copyWith(content: updatedContent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    if (widget.currentUserUid == null) return;
    
    final isCommentAuthor = comment.authorId == widget.currentUserUid;
    if (!_isAdmin && !isCommentAuthor) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment?'),
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

    if (shouldDelete != true) return;

    try {
      await FeedService.deleteComment(
        feedId: widget.feedId,
        commentId: comment.commentId,
      );

      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.commentId == comment.commentId);
        if (_replyingTo?.commentId == comment.commentId) {
          _replyingTo = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header / Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Comments",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Iconsax.close_circle,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments List
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const WaitingLoading();
                }
                if (_comments.isEmpty) return _buildEmptyState();

                return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child:  ListView.separated(
                      controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 24),
                    itemBuilder: (context, index) =>
                        _buildCommentItem(_comments[index]),
                  ),
                );
              },
            ),
          ),

          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _commentAuthors[_replyingTo!.authorId]?.name ??
                              _replyingTo!.authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          _replyingTo!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearReply,
                  ),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final isOwner = widget.currentUserUid == comment.authorId;
    final liveAuthor = _commentAuthors[comment.authorId];
    final authorName = liveAuthor?.name ?? comment.authorName;
    final authorAvatar = liveAuthor?.avatar ?? comment.authorAvatar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCommentAuthorProfile(comment.authorId),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            backgroundImage: NetworkImage(
              authorAvatar.isNotEmpty
                  ? authorAvatar
                  : AppStrings.emptyProfilePhotoUrl,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => _toggleReaction(comment, "❤️"),
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reply),
                      title: const Text("Reply"),
                      onTap: () {
                        Navigator.pop(context);
                        _setReply(comment);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite),
                      title: const Text("React ❤️"),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleReaction(comment, "❤️");
                      },
                    ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text("Edit"),
                        onTap: () {
                          Navigator.pop(context);
                          _editComment(comment);
                        },
                      ),
                    if (_isAdmin)
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text("Delete"),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteComment(comment);
                        },
                      ),
                  ],
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => _openCommentAuthorProfile(comment.authorId),
                      child: Text(
                        authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt, locale: 'en_short'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (comment.replyToCommentId != null)
                  _buildReplyPreview(comment),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleReaction(comment, "❤️"),
                      child: Text(
                        "Like",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _setReply(comment),
                      child: Text(
                        "Reply",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (comment.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      children: comment.reactions.entries.map((e) {
                        return GestureDetector(
                          onTap: () => _toggleReaction(comment, e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Text(
                              "${e.key} ${e.value.length}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(CommentModel comment) {
    final replied = _comments.firstWhere(
      (c) => c.commentId == comment.replyToCommentId,
      orElse: () => CommentModel(
        commentId: '',
        authorId: '',
        authorName: 'Deleted',
        authorAvatar: '',
        content: 'Comment not found',
        createdAt: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _commentAuthors[replied.authorId]?.name ?? replied.authorName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            replied.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: "Share your thoughts...",
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _isPosting ? null : _addComment,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Iconsax.send_1, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.message,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No comments yet",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Be the first to share your thoughts.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}