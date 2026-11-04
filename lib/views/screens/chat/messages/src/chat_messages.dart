import 'dart:async';
import 'dart:io' show File, Directory; // used in non-web branches only
import 'package:flutter/foundation.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
// Clipboard (paste screenshots / images / files) and drag & drop. Only the
// names we use are imported, so nothing clashes with the app's own classes.
import 'package:super_clipboard/super_clipboard.dart'
    show
        ClipboardReadEvent,
        ClipboardReader,
        ClipboardEvents,
        DataReader,
        DataReaderFile,
        FileFormat,
        Formats,
        SystemClipboard;
import 'package:super_drag_and_drop/super_drag_and_drop.dart'
    show DropOperation, DropRegion;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';

part 'chat_data.dart';
part 'chat_bubble.dart';
part 'group_viewed_by_indicator.dart';
part 'reaction_users_viewer.dart';
part 'voice_message.dart';
part 'input_bar.dart';
part 'attachment_intake.dart';
part 'chat_options.dart';
part 'chat_top_bar.dart';
part 'chat_members_panel.dart';
part 'forward_message_dialog.dart';
part 'pinned_messages_bar.dart';
part 'utility.dart';
part 'pending_message.dart';

/// The main screen for displaying chat messages.
///
/// This widget sets up the stream for messages and handles the business logic
/// for marking messages as "seen" in the background.
class ChatMessages extends StatefulWidget {
  final ChatModel chat;
  final String currentUser;
  final String opponentUid;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  const ChatMessages({
    super.key,
    required this.chat,
    required this.currentUser,
    required this.opponentUid,
    this.onOpenChat,
  });

  @override
  State<ChatMessages> createState() => _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  late Stream<List<MessagesModel>> _stream;
  StreamSubscription<List<MessagesModel>>? _subscription;
  bool _isSearching = false;
  String _searchQuery = '';
  // Desktop: "Members" side panel (group chats only).
  bool _membersOpen = false;

  // Keeps the conversation (StreamBuilder + scroll position) alive when the
  // members panel opens/closes. Without this, moving the body into a Row
  // rebuilt the StreamBuilder, which re-subscribed to a BROADCAST stream,
  // missed the initial snapshot and stayed on the loading spinner forever.
  final GlobalKey _chatBodyKey = GlobalKey();

  @override
  void didUpdateWidget(covariant ChatMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.uid != widget.chat.uid) _membersOpen = false;
  }

  // Owns the scroll position for the message list so the pinned-messages
  // bar can jump to (and highlight) a specific message.
  final ScrollController _scrollController = ScrollController();
  List<MessagesModel> _latestChats = [];
  late final ChatScrollRegistry _scrollRegistry;

  // Lets the drop zone (which covers the whole conversation) hand dropped
  // files to the input bar.
  final GlobalKey<_ChatInputBarState> _inputKey =
      GlobalKey<_ChatInputBarState>();

  @override
  void initState() {
    super.initState();

    _scrollRegistry = ChatScrollRegistry(
      scrollController: _scrollController,
      getMessages: () => _latestChats,
      // All messages for this chat are already streamed in (no pagination
      // in this build), so there's nothing more to load on demand.
      loadMore: () async => false,
    );

    _stream = ChatService.getChatMessagesStream(
      uid: widget.chat.uid ?? '',
    ).asBroadcastStream();

    // Clear everything unread as soon as the chat is opened (covers messages
    // that are not part of the rendered list too).
    // This chat is now open: hide ONLY its unread badge.
    ChatService.setActiveChat(widget.chat.uid);
    ChatService.markChatMessagesAsSeen(widget.chat.uid ?? '');

    // Side-effect only: whenever new messages arrive while the chat is open,
    // mark them as seen. Does NOT call setState or manage UI data.
    _subscription = _stream.listen(_markMessagesAsSeen);
  }

  /// A background task to mark incoming messages as seen.
  void _markMessagesAsSeen(List<MessagesModel> messages) {
    final uid = widget.currentUser;
    final hasUnseen = messages.any(
      (msg) => !msg.seenBy.contains(uid) && msg.senderId != uid,
    );
    if (hasUnseen) {
      ChatService.markChatMessagesAsSeen(widget.chat.uid ?? '');
    }
  }

  @override
  void dispose() {
    ChatService.clearActiveChat(widget.chat.uid ?? '');
    _subscription?.cancel();
    _scrollController.dispose();
    _scrollRegistry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ChatData(
      uid: widget.chat.uid ?? '',
      currentUser: widget.currentUser,
      isGroupChat: widget.chat.isGroupChat,
      chat: widget.chat,
      scrollRegistry: _scrollRegistry,
      child: Scaffold(
        appBar: kIsMobile || width < 1000
            ? ChatTopBar(
                userUid: widget.opponentUid,
                currentUserUid: widget.currentUser,
                lastSeen: DateTime.now().formatTime,
                chat: widget.chat,
                isSearching: _isSearching,

                onSearchChanged: (value) {
                  setState(() {
                    _isSearching = true;
                    _searchQuery = value;
                  });
                },

                onSearchClose: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  });
                },
              )
            : ChatTopBarDesktop(
                userUid: widget.opponentUid,
                currentUserUid: widget.currentUser,
                lastSeen: DateTime.now().formatTime,
                chat: widget.chat,
                isSearching: _isSearching,
                isMembersOpen: _membersOpen,
                onMembersTap: () => setState(() => _membersOpen = !_membersOpen),

                onSearchChanged: (value) {
                  setState(() {
                    _isSearching = true;
                    _searchQuery = value;
                  });
                },

                onSearchClose: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                  });
                },
              ),
        body: LayoutBuilder(
          builder: (context, box) {
            final chatBody = KeyedSubtree(
              key: _chatBodyKey,
              child: SafeArea(
          child: ChatDropZone(
            canAccept: () => _inputKey.currentState?.canAcceptAttachments ?? false,
            onImported: (r) => _inputKey.currentState?.receiveImport(r),
            child: Container(
            // WhatsApp-style wallpaper base tone: a warm tan in light mode,
            // a deep slate in dark mode, matching the reference rather
            // than the app's neutral scaffold color.
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0B141A)
                : const Color(0xFFE5DDD5),
            child: StreamBuilder<List<MessagesModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const WaitingLoading();
                } else if (snapshot.hasError) {
                  return ErrorDisplay(error: snapshot.error.toString());
                }

                final allChats = snapshot.data ?? [];
                _latestChats = allChats;

                final chats = _searchQuery.isEmpty
                    ? allChats
                    : allChats.where((msg) {
                        final text = (msg.message).toLowerCase();

                        return text.contains(_searchQuery.toLowerCase());
                      }).toList();

                final pinnedMessages = allChats.where((m) => m.isPinned).toList()
                  ..sort(
                    (a, b) => (a.pinnedTimeStamp ?? a.timestamp)
                        .compareTo(b.pinnedTimeStamp ?? b.timestamp),
                  );

                // The latest message sent by the current user, taken from the
                // full (un-search-filtered) message stream. This is what the
                // single, conversation-level "Viewed by" indicator is
                // anchored to for group chats, independent of search state.
                final latestOutgoingMessage = allChats.firstWhereOrNull(
                  (m) => m.senderId == widget.currentUser,
                );

                return Column(
                  children: [
                    if (pinnedMessages.isNotEmpty)
                      PinnedMessagesBar(
                        pinnedMessages: pinnedMessages,
                        onTapMessage: (uid) =>
                            _scrollRegistry.scrollToMessage(uid),
                      ),
                    Expanded(
                      // Pass the raw list to BuildSliverChat
                      child: BuildSliverChat(
                        chats: chats,
                        scrollController: _scrollController,
                        searchQuery: _searchQuery,
                        onOpenChat: widget.onOpenChat,
                        latestOutgoingMessage: latestOutgoingMessage,
                      ),
                    ),
                    ChatInputBar(key: _inputKey, chat: widget.chat),
                  ],
                );
              },
                ),
            ),
          ),
          ),
            );

            // Members side panel: desktop layout + group chats only.
            final bool desktopLayout =
                !(kIsMobile || MediaQuery.of(context).size.width < 1000);
            if (!_membersOpen || !desktopLayout || !widget.chat.isGroupChat) {
              return chatBody;
            }

            final panel = ChatMembersPanel(
              key: ValueKey('members_${widget.chat.uid}'),
              chat: widget.chat,
              currentUserUid: widget.currentUser,
              onOpenChat: widget.onOpenChat,
              onClose: () => setState(() => _membersOpen = false),
            );

            // Enough room: conversation + panel side by side (Bitrix).
            if (box.maxWidth >= 760) {
              return Row(
                children: [
                  Expanded(child: chatBody),
                  SizedBox(width: 320, child: panel),
                ],
              );
            }

            // Narrow chat pane: float the panel over the conversation.
            return Stack(
              children: [
                chatBody,
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: box.maxWidth < 320 ? box.maxWidth : 320,
                  child: Material(elevation: 8, child: panel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// This widget takes a flat list of messages, groups them by date,
/// and builds the reversible chat list with date separators.
class BuildSliverChat extends StatefulWidget {
  final List<MessagesModel> chats;
  final String searchQuery;
  final Function(ChatModel chat, String opponentUid)? onOpenChat;
  final ScrollController scrollController;

  /// The latest message sent by the current user (independent of any
  /// active search filter). Used to anchor the single, conversation-level
  /// "Viewed by" indicator for group chats. Null if the current user
  /// hasn't sent a message yet.
  final MessagesModel? latestOutgoingMessage;

  const BuildSliverChat({
    super.key,
    required this.chats,
    required this.scrollController,
    this.searchQuery = '',
    this.onOpenChat,
    this.latestOutgoingMessage,
  });

  @override
  State<BuildSliverChat> createState() => _BuildSliverChatState();
}

class _BuildSliverChatState extends State<BuildSliverChat> {
  bool _showGoToBottomButton = false;
  int _pendingCount = PendingMessageStore.instance.length;

  @override
  void initState() {
    widget.scrollController.addListener(_scrollListener);
    PendingMessageStore.instance.addListener(_onPendingChanged);
    super.initState();
  }

  /// When the user sends something new, jump to the bottom so it is visible.
  void _onPendingChanged() {
    final count = PendingMessageStore.instance.length;
    if (count > _pendingCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollController.hasClients) return;
        widget.scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
    _pendingCount = count;
  }

  @override
  void didUpdateWidget(covariant BuildSliverChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scrollListener);
      widget.scrollController.addListener(_scrollListener);
    }
  }

  void _scrollListener() {
    if (!mounted) return;
    // Show "Go to Bottom" if not already at the bottom (i.e. pixels > 50)
    if (widget.scrollController.offset > 50 && !_showGoToBottomButton) {
      setState(() {
        _showGoToBottomButton = true;
      });
    }
    // Hide it when near the bottom
    else if (widget.scrollController.offset <= 50 && _showGoToBottomButton) {
      setState(() {
        _showGoToBottomButton = false;
      });
    }
  }

  @override
  void dispose() {
    PendingMessageStore.instance.removeListener(_onPendingChanged);
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  /// Groups a flat list of chats into a map keyed by date labels.
  Map<String, List<MessagesModel>> _groupChatsByDate(
    List<MessagesModel> chats,
  ) {
    Map<String, List<MessagesModel>> grouped = {};

    for (var chat in chats) {
      final date = chat.timestamp;
      final now = DateTime.now();
      String key;

      if (_isSameDate(date, now)) {
        key = 'Today';
      } else if (_isSameDate(date, now.subtract(const Duration(days: 1)))) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMM d, yyyy').format(date);
      }

      grouped.putIfAbsent(key, () => []).add(chat);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final aDate = _parseDateKey(a.key);
        final bDate = _parseDateKey(b.key);
        return aDate.compareTo(bDate);
      });

    final sortedMap = <String, List<MessagesModel>>{};
    for (final entry in sortedEntries) {
      sortedMap[entry.key] = entry.value;
    }

    return sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever a pending (uploading) message is added / updated / done.
    return ListenableBuilder(
      listenable: PendingMessageStore.instance,
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final chatData = ChatData.of(context);
    final uid = chatData.uid;
    final currentUser = chatData.currentUser;
    final scrollRegistry = chatData.scrollRegistry;

    // Pinned messages stay inline in the normal flow (they still show a
    // "Pinned" tag on the bubble itself) - the fixed PinnedMessagesBar
    // above the list is what surfaces them, matching Bitrix's behaviour.
    final groupedChats = _groupChatsByDate(widget.chats);

    final List<Widget> slivers = [];

    for (var entry in groupedChats.entries) {
      final dateLabel = entry.key;
      final chats = entry.value;

      slivers.add(
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final message = chats[index];
            final messageUid = message.uid;
            return ValueListenableBuilder<String?>(
              key: ValueKey(messageUid),
              valueListenable: scrollRegistry.highlightedUid,
              builder: (context, highlightedUid, child) {
                return AnimatedContainer(
                  key: messageUid != null
                      ? scrollRegistry.keyFor(messageUid)
                      : null,
                  duration: const Duration(milliseconds: 300),
                  color: (messageUid != null && highlightedUid == messageUid)
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: child,
                );
              },
              child: ChatBubble(
                chatUid: uid,
                message: message,
                isSender: message.senderId == currentUser,
                // The 'isLast' logic seems to be for seenBy.
                // Note: This logic assumes chats are sorted newest-to-oldest per day.
                // If they are sorted oldest-to-newest, this should be `index == chats.length - 1`.
                // Based on `reverse: true` in CustomScrollView, assuming 0 is the *newest*.
                isLast: message.senderId == currentUser && index == 0,
                onOpenChat: widget.onOpenChat,
              ),
            );
          }, childCount: chats.length),
        ),
      );
    }

    // ── Group-chat "Viewed by" indicator ──────────────────────────────
    // A single, conversation-level indicator (Bitrix-style) shown once at
    // the very bottom of the message list — never per-message. Added last
    // here (before the sliver list is reversed below) so it ends up
    // rendered below the latest message, just above the composer.
    // Hidden while searching so it doesn't sit awkwardly under a filtered
    // result set that may not even include the latest message.
    if (chatData.isGroupChat && widget.searchQuery.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: GroupViewedByIndicator(
            latestOutgoingMessage: widget.latestOutgoingMessage,
            currentUser: currentUser,
            participants: chatData.chat.participants,
          ),
        ),
      );
    }

    // Messages that are still uploading / sending go at the very bottom.
    // Skip any that Firestore already echoed back (same pre-generated id).
    if (widget.searchQuery.isEmpty) {
      final sentIds = widget.chats.map((m) => m.uid).toSet();
      final pending = PendingMessageStore.instance
          .forChat(uid)
          .where((p) => !sentIds.contains(p.id))
          .toList();
      if (pending.isNotEmpty) {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final p = pending[index];
              return PendingChatBubble(key: ValueKey(p.id), message: p);
            }, childCount: pending.length),
          ),
        );
      }
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right:8.0),
          child: Scrollbar(
                      controller: widget.scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: CustomScrollView(
              controller: widget.scrollController,
              reverse: true, // This makes the list start at the bottom
              slivers: slivers.reversed
                  .toList(), // This reverses the *order of groups* (e.g., Today, Yesterday)
            ),
          ),
        ),
        if (_showGoToBottomButton)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  widget.scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                icon: Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(
                  "Go to Bottom",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- TOP-LEVEL HELPER FUNCTIONS ---

/// Checks if two DateTimes are on the same calendar day.
bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

/// Parses a date key ('Today', 'Yesterday', or 'MMM d, yyyy') into a DateTime.
DateTime _parseDateKey(String key) {
  final now = DateTime.now();
  if (key == 'Today') {
    return DateTime(now.year, now.month, now.day);
  } else if (key == 'Yesterday') {
    final yesterday = now.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day);
  } else {
    return DateFormat('MMM d, yyyy').parse(key);
  }
}

class ThreadSheet extends StatefulWidget {
  final MessagesModel parentMessage;
  final ChatModel chat;

  const ThreadSheet({
    super.key,
    required this.parentMessage,
    required this.chat,
  });

  static void show(
    BuildContext context,
    MessagesModel parentMessage,
    ChatModel chat,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ThreadSheet(parentMessage: parentMessage, chat: chat),
    );
  }

  @override
  State<ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<ThreadSheet> {
  final GlobalKey<_ChatInputBarState> _inputKey =
      GlobalKey<_ChatInputBarState>();

  @override
  Widget build(BuildContext context) {
    final parentMessage = widget.parentMessage;
    final chat = widget.chat;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return ChatDropZone(
      canAccept: () => _inputKey.currentState?.canAcceptAttachments ?? false,
      onImported: (r) => _inputKey.currentState?.receiveImport(r),
      child: Container(
      height: screenHeight * 0.85,
      margin: EdgeInsets.only(top: 24, bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Iconsax.message_programming,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Thread Reply",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parentMessage.senderName ?? "User",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    parentMessage.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(),

            Expanded(
              child: StreamBuilder<List<MessagesModel>>(
                stream: ChatService.getThreadMessagesStream(
                  chatId: chat.uid ?? '',
                  parentMessageId: parentMessage.uid ?? '',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  final replies = snapshot.data ?? [];

                  return ListenableBuilder(
                    listenable: PendingMessageStore.instance,
                    builder: (context, _) {
                      final sentIds = replies.map((r) => r.uid).toSet();
                      final pending = PendingMessageStore.instance
                          .forChat(chat.uid ?? '', threadId: parentMessage.uid)
                          .where((p) => !sentIds.contains(p.id))
                          .toList();

                      if (replies.isEmpty && pending.isEmpty) {
                        return Center(
                          child: Text(
                            "No replies yet. Be the first to reply!",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: pending.length + replies.length,
                        itemBuilder: (context, index) {
                          if (index < pending.length) {
                            final p = pending[index];
                            return PendingChatBubble(
                              key: ValueKey(p.id),
                              message: p,
                            );
                          }
                          final reply = replies[index - pending.length];
                          final isSender =
                              reply.senderId == parentMessage.senderId;
                          return ChatBubble(
                            chatUid: chat.uid ?? '',
                            message: reply,
                            isSender: isSender,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),

            ChatInputBar(
              key: _inputKey,
              chat: chat,
              threadId: parentMessage.uid,
            ),
          ],
        ),
      ),
      ),
    );
  }
}