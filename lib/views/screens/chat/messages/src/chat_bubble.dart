part of 'chat_messages.dart';

class ChatBubble extends StatefulWidget {
  final String chatUid;
  final MessagesModel message;
  final bool isSender;
  final bool isLast;
  final bool isPinned;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;

  const ChatBubble({
    super.key,
    required this.chatUid,
    required this.message,
    required this.isSender,
    this.isLast = false,
    this.isPinned = false,
    this.onOpenChat,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  Offset _slideOffset = Offset.zero;
  bool _showSlideIcon = false;

  // Overlay & Hover Logic
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink(); // whole row (mobile long-press menu)
  final LayerLink _bubbleLink = LayerLink(); // the bubble itself (desktop chips)
  final LayerLink _chipLink = LayerLink(); // the small reaction chip
  Timer? _hoverTimer;
  bool _isMenuHovered = false;
  bool _isBubbleHovered = false;
  bool _isPopupOpen = false;

  // Desktop / web (Bitrix style) hover state
  bool _chipHovered = false;
  bool _pickerHovered = false;
  bool _actionsHovered = false;
  bool _pickerVisible = false;
  // Picker placement, decided from the free space around the chip so it is
  // never cut off by the screen edge.
  bool _pickerExtendsRight = true;
  bool _pickerBelow = false;
  final GlobalKey _chipKey = GlobalKey();
  static const double _pickerWidth = 260;
  static const double _pickerHeight = 48;

  /// Only ONE bubble may show its hover controls at a time. This is what
  /// stops the "emoji bar shows on every message" bug: if a hover-exit is
  /// ever missed (fast mouse, scrolling, overlay disposed under the
  /// pointer), the stale bubble is hidden as soon as another one is hovered.
  static _ChatBubbleState? _activeBubble;

  late bool _isPinned;
  late MessagesModel _msg;
  MessagesModel? _replyChat;
  bool _isAdmin = false;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _msg = widget.message;
    _isPinned = _msg.isPinned;
    _initReplyMessage();
    _checkAdmin();
    _loadCurrentUid();
  }

  Future<void> _loadCurrentUid() async {
    final uid = await Spdb.getUid();
    if (mounted && uid != _currentUid) setState(() => _currentUid = uid);
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await Spdb.isAdminLoggedIn();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _msg = widget.message;
      _isPinned = _msg.isPinned;
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    if (_activeBubble == this) _activeBubble = null;
    super.dispose();
  }

  void _initReplyMessage() async {
    if (_msg.replyFor != null) {
      final message = await ChatService.getChatMessage(
        chatId: widget.chatUid,
        messageId: _msg.replyFor!,
      );
      if (mounted) setState(() => _replyChat = message);
    }
  }

  // --- Hover Logic with Delay ---

  void _onEnterBubble() {
    _isBubbleHovered = true;
    _showMenu();
  }

  void _onExitBubble() {
    _isBubbleHovered = false;
    _startHideTimer();
  }

  void _onEnterMenu() {
    _isMenuHovered = true;
    _showMenu(); // Cancel any hide timer
  }

  void _onExitMenu() {
    _isMenuHovered = false;
    _startHideTimer();
  }

  // Desktop chips: reaction chip -> opens the emoji picker on hover.
  void _setChipHover(bool v) {
    _chipHovered = v;
    if (v) {
      _hoverTimer?.cancel();
      if (!_pickerVisible && mounted) {
        _decidePickerPlacement();
        setState(() => _pickerVisible = true);
      }
    } else {
      _startHideTimer();
    }
  }

  void _decidePickerPlacement() {
    final box = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screenW = MediaQuery.of(context).size.width;
    const margin = 8.0;

    final canRight = rect.left + _pickerWidth <= screenW - margin;
    final canLeft = rect.right - _pickerWidth >= margin;

    // Prefer the natural side (sender chip is on the left of the bubble,
    // incoming chip on the right), but flip when there is no room.
    final preferRight = widget.isSender;
    if (preferRight) {
      _pickerExtendsRight = canRight || !canLeft;
    } else {
      _pickerExtendsRight = !canLeft && canRight;
    }

    // Not enough room above (e.g. first message under the header): open below.
    _pickerBelow = rect.top < _pickerHeight + 12;
  }

  void _setPickerHover(bool v) {
    _pickerHovered = v;
    if (v) {
      _hoverTimer?.cancel();
    } else {
      _startHideTimer();
    }
  }

  void _setActionsHover(bool v) {
    _actionsHovered = v;
    if (v) {
      _hoverTimer?.cancel();
    } else {
      _startHideTimer();
    }
  }

  void _showMenu() {
    _hoverTimer?.cancel();
    if (!kIsMobile) {
      final prev = _activeBubble;
      if (prev != null && prev != this) prev._forceHide();
      _activeBubble = this;
    }
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  /// Hides every hover control immediately and clears all hover flags
  /// (a disposed overlay never fires onExit, so flags must be reset here).
  void _forceHide() {
    _hoverTimer?.cancel();
    _isBubbleHovered = false;
    _isMenuHovered = false;
    _chipHovered = false;
    _pickerHovered = false;
    _actionsHovered = false;
    _isPopupOpen = false;
    if (_overlayController.isShowing) _overlayController.hide();
    if (_activeBubble == this) _activeBubble = null;
    if (mounted && _pickerVisible) {
      setState(() => _pickerVisible = false);
    } else {
      _pickerVisible = false;
    }
  }

  void _startHideTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final anyHover =
          _isBubbleHovered ||
          _isMenuHovered ||
          _chipHovered ||
          _pickerHovered ||
          _actionsHovered;
      // Don't hide while the "..." popup menu is open.
      if (!anyHover && !_isPopupOpen) {
        _forceHide();
        return;
      }
      // Picker is only visible while the chip / picker is hovered.
      final wantPicker = _chipHovered || _pickerHovered;
      if (wantPicker != _pickerVisible) {
        setState(() => _pickerVisible = wantPicker);
      }
    });
  }

  Map<String, VoidCallback> _buildActions(MessageProvider messageProvider) {
    return {
      "reply": () {
        _forceHide();
        messageProvider.replyMessage(_msg);
      },
      if (_canForward) "forward": _openForward,
      "copy": () {
        _forceHide();
        Clipboard.setData(ClipboardData(text: _msg.message));
      },
      if (_isPinned) "unpin": _pinMessage else "pin": _pinMessage,
      if (widget.isSender)
        "edit": () {
          _forceHide();
          messageProvider.editMessage(_msg);
        },
      if (widget.isSender) "delete": _handleDeleteMessage,
    };
  }

  bool get _canForward =>
      _msg.uid != null &&
      (_msg.message.trim().isNotEmpty || _msg.attachments.isNotEmpty);

  void _openForward() {
    _forceHide();
    ForwardMessageDialog.show(
      context,
      message: _msg,
      sourceChatId: widget.chatUid,
      currentUserUid: _currentUid ?? '',
    );
  }

  /// Opens the "..." actions popup next to the small chip (desktop).
  void _openActionsMenu(BuildContext chipContext, MessageProvider provider) {
    final actions = _buildActions(provider);
    final RenderBox button = chipContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(chipContext).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    _isPopupOpen = true;
    showMenu<String>(
      context: chipContext,
      position: position,
      items: [
        for (final i in actions.keys)
          PopupMenuItem(
            value: i,
            child: Text(
              i.capitalizeFirst,
              style: Theme.of(chipContext).textTheme.bodyLarge,
            ),
          ),
      ],
    ).then((value) {
      _isPopupOpen = false;
      if (!mounted) return;
      if (value != null) {
        actions[value]!();
      } else {
        _startHideTimer();
      }
    });
  }

  // --- Gestures ---

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    double dx = details.primaryDelta!;
    setState(() {
      if (widget.isSender && dx < 0) {
        _slideOffset = Offset((_slideOffset.dx + dx).clamp(-60, 0), 0);
        _showSlideIcon = true;
      } else if (!widget.isSender && dx > 0) {
        _slideOffset = Offset((_slideOffset.dx + dx).clamp(0, 60), 0);
        _showSlideIcon = true;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final threshold = widget.isSender
        ? _slideOffset.dx <= -40
        : _slideOffset.dx >= 40;
    if (threshold) _triggerSwipeAction();
    setState(() {
      _slideOffset = Offset.zero;
      _showSlideIcon = false;
    });
  }

  void _triggerSwipeAction() {
    Provider.of<MessageProvider>(context, listen: false).replyMessage(_msg);
  }

  void _onDoubleTap() {
    _addReaction("❤️");
  }

  void _addReaction(String emoji) async {
    // Optimistic UI update could be added here
    final uid = await Spdb.getUid();
    if (uid == null) return;

    if (mounted) _forceHide();

    await ChatService.toggleReaction(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      emoji: emoji,
      userId: uid,
    );

    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
    if (mounted) setState(() => _msg = updated);
  }

  void _pinMessage() async {
    _forceHide();
    await ChatService.togglePin(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      value: !_isPinned,
    );
    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
    if (mounted) {
      setState(() {
        _msg = updated;
        _isPinned = updated.isPinned;
      });
    }
  }

  void _handleDeleteMessage() async {
    _forceHide();
    final confirm = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) =>
          const ConfirmDialog(title: "Delete", content: "Delete this message?"),
    );
    if (confirm != true) return;
    await ChatService.deleteChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );
  }

  void _showMobileChatOptions() async {
    if (!kIsMobile) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Sheet.showSheet(
      context,
      widget: ChatOptions(delete: _isAdmin && widget.isSender, edit: widget.isSender),
      size: 0.4,
    );

    if (result != null && mounted) {
      final provider = Provider.of<MessageProvider>(context, listen: false);
      if (result == 1) provider.editMessage(_msg);
      if (result == 2) _handleDeleteMessage();
      if (result == 3) provider.replyMessage(_msg);
      if (result == 4) Clipboard.setData(ClipboardData(text: _msg.message));
      if (result == 5 && _canForward) _openForward();
    }
  }

  void _onReactionTap(String emoji) async {
    final uid = await Spdb.getUid();
    if (uid == null) return;

    await ChatService.toggleReaction(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
      emoji: emoji,
      userId: uid,
    );

    final updated = await ChatService.getChatMessage(
      chatId: widget.chatUid,
      messageId: _msg.uid!,
    );

    if (mounted) setState(() => _msg = updated);
  }

  // ------------------------------------------------------------------
  // Desktop / web overlay (Bitrix style)
  //   • hover the bubble     -> small 👍 chip on the bubble's bottom edge
  //                             + small "..." chip beside the bubble
  //   • hover the 👍 chip    -> emoji picker pops up above it
  //   • click an emoji / chip-> react
  // ------------------------------------------------------------------
  Widget _buildDesktopOverlay(MessageProvider messageProvider) {
    final isSender = widget.isSender;
    final theme = Theme.of(context);

    BoxDecoration chipDecoration() => BoxDecoration(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: theme.colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.18),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return Stack(
      children: [
        // 1) "..." actions chip, beside the bubble (top corner)
        CompositedTransformFollower(
          link: _bubbleLink,
          showWhenUnlinked: false,
          targetAnchor: isSender ? Alignment.topLeft : Alignment.topRight,
          followerAnchor: isSender ? Alignment.topRight : Alignment.topLeft,
          offset: Offset(isSender ? -6 : 6, 0),
          child: Align(
            alignment: isSender ? Alignment.topRight : Alignment.topLeft,
            child: MouseRegion(
              onEnter: (_) => _setActionsHover(true),
              onExit: (_) => _setActionsHover(false),
              child: Builder(
                builder: (chipContext) => GestureDetector(
                  onTap: () => _openActionsMenu(chipContext, messageProvider),
                  child: Tooltip(
                    message: 'More',
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: chipDecoration(),
                      child: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2) small 👍 reaction chip on the bubble's bottom edge.
        //    Placed on the side opposite to the existing reaction chips.
        CompositedTransformFollower(
          link: _bubbleLink,
          showWhenUnlinked: false,
          targetAnchor: isSender ? Alignment.bottomLeft : Alignment.bottomRight,
          followerAnchor: isSender
              ? Alignment.bottomLeft
              : Alignment.bottomRight,
          // Mostly below the bubble edge so it doesn't cover the reactions
          // that now sit inside the bubble.
          offset: Offset(isSender ? 10 : -10, 18),
          child: Align(
            alignment: isSender ? Alignment.bottomLeft : Alignment.bottomRight,
            child: CompositedTransformTarget(
              link: _chipLink,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => _setChipHover(true),
                onExit: (_) => _setChipHover(false),
                child: GestureDetector(
                  onTap: () => _addReaction("👍"),
                  child: Container(
                    key: _chipKey,
                    width: 26,
                    height: 26,
                    decoration: chipDecoration(),
                    child: const Icon(
                      Icons.thumb_up_alt_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3) emoji picker, only while the chip / picker is hovered.
        //    Side (left/right) and vertical position are chosen from the
        //    free space so it never goes behind the screen edge.
        if (_pickerVisible)
          CompositedTransformFollower(
            link: _chipLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment(
              _pickerExtendsRight ? -1 : 1,
              _pickerBelow ? 1 : -1,
            ),
            followerAnchor: Alignment(
              _pickerExtendsRight ? -1 : 1,
              _pickerBelow ? -1 : 1,
            ),
            offset: Offset(0, _pickerBelow ? 4 : -4),
            child: Align(
              alignment: Alignment(
                _pickerExtendsRight ? -1 : 1,
                _pickerBelow ? -1 : 1,
              ),
              child: MouseRegion(
                onEnter: (_) => _setPickerHover(true),
                onExit: (_) => _setPickerHover(false),
                child: _EmojiPickerBar(
                  alignment: Alignment(
                    _pickerExtendsRight ? -1 : 1,
                    _pickerBelow ? -1 : 1,
                  ),
                  onSelected: _addReaction,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (BuildContext context) {
            // Desktop / web: Bitrix style chips + picker.
            if (!kIsMobile) return _buildDesktopOverlay(messageProvider);

            // Mobile (long press): the original full menu.
            return CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: widget.isSender
                  ? Alignment.topRight
                  : Alignment.topLeft,
              followerAnchor: widget.isSender
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              offset: const Offset(0, -6),
              child: Align(
                alignment: widget.isSender
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: MouseRegion(
                  onEnter: (_) => _onEnterMenu(),
                  onExit: (_) => _onExitMenu(),
                  child: _ChatBubbleHoverMenu(
                    isSender: widget.isSender,
                    onReaction: _addReaction,
                    onMenuStateChanged: (isOpen) {
                      _isPopupOpen = isOpen;
                      if (!isOpen) _startHideTimer();
                    },
                    actions: _buildActions(messageProvider),
                  ),
                ),
              ),
            );
          },
          child: GestureDetector(
            // Touch only: on desktop/web a mouse double-click must select a
            // word of the message text (reactions use the hover chip there).
            onDoubleTap: kIsMobile ? _onDoubleTap : null,
            onLongPress: () {
              if (kIsMobile) {
                _onEnterMenu();
              }
            },
            onLongPressCancel: () {
              if (kIsMobile) {
                _onExitMenu();
              }
            },
            child: _ChatBubbleCore(
              slideOffset: _slideOffset,
              showSlideIcon: _showSlideIcon,
              isSender: widget.isSender,
              message: _msg,
              replyChat: _replyChat,
              isLast: widget.isLast,
              isPinned: _isPinned,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onLongPress: _showMobileChatOptions,
              onReactionTap: _onReactionTap,
              currentUserId: _currentUid,
              onOpenChat: widget.onOpenChat,
              // Hover is tracked on the BUBBLE only (not the whole row), so
              // empty space beside a short message no longer triggers it.
              bubbleLink: kIsMobile ? null : _bubbleLink,
              onBubbleEnter: kIsMobile ? null : _onEnterBubble,
              onBubbleExit: kIsMobile ? null : _onExitBubble,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubbleCore extends StatelessWidget {
  final Offset slideOffset;
  final bool showSlideIcon;
  final bool isSender;
  final MessagesModel message;
  final MessagesModel? replyChat;
  final bool isLast;
  final bool isPinned;
  final ValueChanged<DragUpdateDetails> onHorizontalDragUpdate;
  final ValueChanged<DragEndDetails> onHorizontalDragEnd;
  final VoidCallback onLongPress;
  final Function(String)? onReactionTap;
  final String? currentUserId;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  final LayerLink? bubbleLink;
  final VoidCallback? onBubbleEnter;
  final VoidCallback? onBubbleExit;

  const _ChatBubbleCore({
    required this.slideOffset,
    required this.showSlideIcon,
    required this.isSender,
    required this.message,
    required this.replyChat,
    required this.isLast,
    required this.isPinned,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.onLongPress,
    this.onReactionTap,
    this.currentUserId,
    this.onOpenChat,
    this.bubbleLink,
    this.onBubbleEnter,
    this.onBubbleExit,
  });

  /// Anchors the desktop hover chips to the bubble and tracks hover on it.
  Widget _wrapHover(Widget child) {
    if (bubbleLink == null) return child;
    return CompositedTransformTarget(
      link: bubbleLink!,
      child: MouseRegion(
        onEnter: (_) => onBubbleEnter?.call(),
        onExit: (_) => onBubbleExit?.call(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatData = ChatData.of(context);
    final isGroupChat = chatData.isGroupChat;
    return Transform.translate(
      offset: slideOffset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (showSlideIcon)
            Positioned.fill(
              child: Align(
                alignment: isSender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.reply,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: isSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: AppColors.orange),
                      SizedBox(width: 4),
                      Text(
                        "Pinned",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              if ((!isSender && isLast) || (isGroupChat && !isSender)) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    CacheService.getUserByUid(message.senderId)?.name ??
                        'User',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isSender) ...[
                    _ChatBubbleSenderAvatar(senderId: message.senderId),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isSender
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _wrapHover(
                          _ChatBubbleMessageBox(
                            isSender: isSender,
                            message: message,
                            replyChat: replyChat,
                            onOpenChat: onOpenChat,
                            currentUserId: currentUserId,
                            onReactionTap: onReactionTap,
                          ),
                        ),
                        // Text messages show their reactions INSIDE the
                        // bubble (see _ChatBubbleMessageBox). Only
                        // attachment-only messages (no text bubble) keep
                        // them underneath.
                        if (message.reactions.isNotEmpty &&
                            message.message.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _ReactionChips(
                              reactions: message.reactions,
                              isSender: isSender,
                              currentUserId: currentUserId,
                              onTap: onReactionTap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (isSender) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.seenBy.isNotEmpty ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.seenBy.isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubbleMessageBox extends StatefulWidget {
  final bool isSender;
  final MessagesModel message;
  final MessagesModel? replyChat;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  final String? currentUserId;
  final Function(String)? onReactionTap;

  const _ChatBubbleMessageBox({
    required this.isSender,
    required this.message,
    required this.replyChat,
    this.onOpenChat,
    this.currentUserId,
    this.onReactionTap,
  });

  @override
  State<_ChatBubbleMessageBox> createState() => _ChatBubbleMessageBoxState();
}

class _ChatBubbleMessageBoxState extends State<_ChatBubbleMessageBox> {
  Timer? hoverTimer;

  @override
  void dispose() {
    hoverTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _openChat(BuildContext context, MentionModel mention) async {
    final cid = await Spdb.getCid();
    final uid = await Spdb.getUid();
    final opponentUid = mention.uid;

    if (uid == null) return;

    String? chatId = await ChatService.getChatUid(opponentUid);

    chatId ??= await ChatService.createIndividualChat(userId: opponentUid);

    final doc = await FirebaseFirestore.instance
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.chats.name)
        .doc(chatId)
        .get();

    if (!doc.exists) return;

    final chat = ChatModel.fromMap(doc.id, doc.data()!);

    // 🔹 Step 4: Navigate
    if (!kIsMobile && widget.onOpenChat != null) {
      widget.onOpenChat!(chat, opponentUid);
      return;
    }

    Navigate.route(
      context,
      ChatMessages(chat: chat, currentUser: uid, opponentUid: opponentUid),
    );
  }

  OverlayEntry? _overlayEntry;

  // void _showProfileOverlay(
  //   BuildContext context,
  //   Offset globalPosition,
  //   MentionModel mention,
  // ) {
  //   _hideProfileOverlay(); // prevent stacking

  //   final user = CacheService.adminByUid(mention.uid);
  //   if (user == null) return;

  //   final overlay = Overlay.of(context);
  //   final renderBox = overlay.context.findRenderObject() as RenderBox;

  //   final localOffset = renderBox.globalToLocal(globalPosition);

  //   final screenWidth = MediaQuery.of(context).size.width;
  //   final left = (localOffset.dx.clamp(10, screenWidth - 220)).toDouble();
  //   _overlayEntry = OverlayEntry(
  //     builder: (context) => Positioned(
  //       left: left,
  //       top: localOffset.dy + 20,
  //       child: Material(
  //         color: Colors.transparent,
  //         child: Container(
  //           constraints: const BoxConstraints(maxWidth: 200),
  //           padding: const EdgeInsets.all(8),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(10),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withValues(alpha: 0.15),
  //                 blurRadius: 10,
  //               ),
  //             ],
  //           ),
  //           child: CreatedByWidget(userData: user),
  //         ),
  //       ),
  //     ),
  //   );
  //   overlay.insert(_overlayEntry!);
  // }

  void _hideProfileOverlay() {
    hoverTimer?.cancel();
    hoverTimer = Timer(const Duration(milliseconds: 150), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s\)\]\}]+)');
    final match = urlRegex.firstMatch(widget.message.message);
    final url = match?.group(0);

    return Column(
      crossAxisAlignment: widget.isSender
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (widget.message.message.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSender
                  ? null
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              gradient: widget.isSender
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0052D4),
                        Color(0xFF4364F7),
                        Color(0xFF6FB1FC),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: widget.isSender
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: widget.isSender
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSender
                      ? const Color(0xFF4364F7).withValues(alpha: 0.28)
                      : Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: widget.isSender ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.forwardFrom != null)
                  _forwardedLabel(context),
                if (widget.replyChat != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
                          CacheService.getUserByUid(
                                widget.replyChat!.senderId,
                              )?.name ??
                              'User',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyChat!.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                _buildMessageWithMentions(context, widget.message.message),
                // Reactions live INSIDE the bubble (Bitrix style).
                if (widget.message.reactions.values.any((u) => u.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _ReactionChips(
                      reactions: widget.message.reactions,
                      isSender: widget.isSender,
                      currentUserId: widget.currentUserId,
                      onTap: widget.onReactionTap,
                    ),
                  ),
              ],
            ),
          ),

        // Forwarded attachment without text (no bubble): label above it.
        if (widget.message.forwardFrom != null &&
            widget.message.message.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
            child: _forwardedLabel(context, onBubble: false),
          ),

        // --- Attachment / URL Preview ---
        if (url != null && widget.message.attachments.isEmpty) ...[
          UrlPreview(url: url, isSender: widget.isSender),
        ] else if (widget.message.attachments.isNotEmpty) ...[
          AttachmentPreview(
            attachments: widget.message.attachments,
            isSender: widget.isSender,
          ),
        ],
      ],
    );
  }

  /// "↪ Forwarded from <original author>"
  Widget _forwardedLabel(BuildContext context, {bool onBubble = true}) {
    final cs = Theme.of(context).colorScheme;
    final Color color = onBubble && widget.isSender
        ? cs.onPrimary.withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
    final from = widget.message.forwardFrom;
    final name = from == null ? '' : _resolveSenderName(from);

    return Padding(
      padding: EdgeInsets.only(bottom: onBubble ? 4 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.send_2, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name.isEmpty || name == 'User'
                  ? 'Forwarded'
                  : 'Forwarded from $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageWithMentions(BuildContext context, String text) {
    final Color textColor = widget.isSender
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final mentions = widget.message.mentions ?? [];
    if (mentions.isEmpty) {
      return Text(text, style: TextStyle(color: textColor));
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    final sortedMentions = [...mentions]
      ..sort((a, b) => (a.start ?? 0).compareTo(b.start ?? 0));

    for (final mention in sortedMentions) {
      final start = mention.start;
      final end = mention.end;

      if (start == null || end == null) continue;

      if (start < 0 ||
          end < 0 ||
          start > text.length ||
          end > text.length ||
          start >= end) {
        continue;
      }

      // Normal text before mention
      if (currentIndex < start) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, start),
            style: TextStyle(color: textColor),
          ),
        );
      }

      String mentionText = text.substring(start, end);
      if (mentionText.startsWith('@')) {
        mentionText = mentionText.substring(1);
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Builder(
            builder: (context) {
              String mentionText = text.substring(start, end);

              if (mentionText.startsWith('@')) {
                mentionText = mentionText.substring(1);
              }

              return MouseRegion(
                onEnter: (event) {
                  hoverTimer?.cancel();
                },
                onExit: (event) {
                  _hideProfileOverlay();
                },
                child: GestureDetector(
                  onTap: () => _openChat(context, mention),

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mentionText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      currentIndex = end;
    }

    // Remaining text
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: textColor),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _ReactionChips extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isSender;
  final String? currentUserId;
  final Function(String)? onTap;
  const _ReactionChips({
    required this.reactions,
    required this.isSender,
    this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // reactions = { "😂": ["u1","u2"], "❤️": ["u3"] }
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    final touchUi = _useTouchReactionUi();

    return Wrap(
      alignment: isSender ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: entries.map((entry) {
        return _ReactionChip(
          key: ValueKey('reaction_${entry.key}'),
          emoji: entry.key,
          users: entry.value,
          isSender: isSender,
          currentUserId: currentUserId,
          // Mouse: click toggles your reaction, hover shows who reacted.
          // Touch: tap opens the "who reacted" sheet (own entry removable).
          onTap: () {
            if (touchUi) {
              _showReactionUsersSheet(
                context,
                reactions: reactions,
                currentUserId: currentUserId,
                initialEmoji: entry.key,
                onRemoveOwn: (emoji) => onTap?.call(emoji),
              );
            } else {
              onTap?.call(entry.key);
            }
          },
        );
      }).toList(),
    );
  }
}

class _ChatBubbleHoverMenu extends StatefulWidget {
  final bool isSender;
  final Function(String) onReaction;
  final Map<String, VoidCallback> actions;
  final ValueChanged<bool>? onMenuStateChanged; // FIX: New callback

  const _ChatBubbleHoverMenu({
    required this.isSender,
    required this.onReaction,
    required this.actions,
    this.onMenuStateChanged, // FIX: New callback
  });

  @override
  State<_ChatBubbleHoverMenu> createState() => _ChatBubbleHoverMenuState();
}

class _ChatBubbleHoverMenuState extends State<_ChatBubbleHoverMenu> {
  @override
  Widget build(BuildContext context) {
    final emojis = ["👍", "❤️", "😂", "😮", "😢", "🔥"];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...emojis.map(
            (e) => _HoverEmoji(emoji: e, onTap: () => widget.onReaction(e)),
          ),
          Container(
            height: 20,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          _HoverIcon(icon: Icons.reply, onTap: widget.actions['reply']),
          _HoverIcon(
            icon: Icons.more_horiz,
            onTap: () {
              final RenderBox button = context.findRenderObject() as RenderBox;
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;

              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlay),
                  button.localToGlobal(
                    button.size.bottomRight(Offset.zero),
                    ancestor: overlay,
                  ),
                ),
                Offset.zero & overlay.size,
              );

              // FIX: Notify parent that menu is open (prevents hide)
              widget.onMenuStateChanged?.call(true);

              showMenu(
                context: context,
                position: position,
                items: [
                  for (var i in widget.actions.keys)
                    PopupMenuItem(
                      value: i,
                      child: Text(
                        i.capitalizeFirst,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                ],
              ).then((value) {
                // FIX: Notify parent that menu is closed
                widget.onMenuStateChanged?.call(false);

                if (!mounted) return;
                if (value != null) {
                  widget.actions[value]!();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Emoji picker pill shown above the reaction chip (Bitrix style).
class _EmojiPickerBar extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final Alignment alignment;
  const _EmojiPickerBar({required this.onSelected, required this.alignment});

  static const _emojis = ["👍", "❤️", "😂", "😮", "😢", "🔥"];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          alignment: alignment,
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in _emojis)
              _HoverEmoji(emoji: e, onTap: () => onSelected(e)),
          ],
        ),
      ),
    );
  }
}

class _HoverEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _HoverEmoji({required this.emoji, required this.onTap});

  @override
  State<_HoverEmoji> createState() => _HoverEmojiState();
}

class _HoverEmojiState extends State<_HoverEmoji> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          // ignore: deprecated_member_use
          transform: Matrix4.identity()..scale(_hover ? 1.2 : 1.0),
          child: Text(
            widget.emoji,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _HoverIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HoverIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      splashRadius: 16,
      onPressed: onTap,
    );
  }
}

class _ChatBubbleSenderAvatar extends StatelessWidget {
  final String senderId;
  const _ChatBubbleSenderAvatar({required this.senderId});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 14,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}