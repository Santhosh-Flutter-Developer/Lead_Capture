part of 'chat_messages.dart';

/// A fixed bar shown directly under the chat app bar, similar to Bitrix24's
/// "Pinned messages" bar. It always stays visible while there is at least
/// one pinned message in the chat (the message itself is NOT removed from
/// the normal message flow - it still shows inline with a "Pinned" tag).
///
/// - Shows the current pinned message (sender + preview).
/// - If there is more than one pinned message, shows a "n/total" counter
///   with chevrons to step through them.
/// - Tapping the message preview scrolls the chat to that exact message
///   and briefly highlights it.
/// - Tapping the counter/list icon opens the full pinned-messages view -
///   an inline dropdown panel on desktop/wide screens (matching Bitrix),
///   or a bottom sheet on mobile/narrow screens.
/// - The close icon unpins the currently shown message.
class PinnedMessagesBar extends StatefulWidget {
  final List<MessagesModel> pinnedMessages;
  final ValueChanged<String> onTapMessage;

  const PinnedMessagesBar({
    super.key,
    required this.pinnedMessages,
    required this.onTapMessage,
  });

  @override
  State<PinnedMessagesBar> createState() => _PinnedMessagesBarState();
}

class _PinnedMessagesBarState extends State<PinnedMessagesBar> {
  int _index = 0;
  bool _showListPanel = false;

  @override
  void didUpdateWidget(covariant PinnedMessagesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinnedMessages.isEmpty) {
      _index = 0;
      _showListPanel = false;
    } else if (_index >= widget.pinnedMessages.length) {
      _index = widget.pinnedMessages.length - 1;
    }
  }

  Future<void> _unpin(MessagesModel message) async {
    final chatData = ChatData.of(context);
    if (message.uid == null) return;
    await ChatService.togglePin(
      chatId: chatData.uid,
      messageId: message.uid!,
      value: false,
    );
  }

  void _onTapList() {
    final width = MediaQuery.of(context).size.width;
    final isMobile = kIsMobile || width < 1000;
    if (isMobile) {
      Sheet.showSheet(
        context,
        size: 0.6,
        widget: PinnedMessagesListView(
          pinnedMessages: widget.pinnedMessages,
          onTapMessage: (uid) {
            Navigator.of(context).pop();
            widget.onTapMessage(uid);
          },
          onUnpin: _unpin,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      setState(() => _showListPanel = !_showListPanel);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinnedMessages.isEmpty) return const SizedBox.shrink();

    final count = widget.pinnedMessages.length;
    final safeIndex = _index.clamp(0, count - 1);
    final message = widget.pinnedMessages[safeIndex];

    final senderName = _resolveSenderName(message.senderId);
    final preview = message.message.isNotEmpty
        ? message.message
        : (message.attachments.isNotEmpty ? 'Attachment' : '');

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: InkWell(
            onTap: () {
              if (message.uid != null) widget.onTapMessage(message.uid!);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.push_pin, size: 16, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _onTapList,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  "Pinned message",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ),
                              Tooltip(
                                message: 'View all pinned messages',
                                child: Icon(
                                  _showListPanel
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "$senderName: $preview",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (count > 1) ...[
                    Text(
                      "${safeIndex + 1}/$count",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Previous pinned message',
                      onPressed: () {
                        setState(() {
                          _index = (safeIndex - 1 + count) % count;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Next pinned message',
                      onPressed: () {
                        setState(() {
                          _index = (safeIndex + 1) % count;
                        });
                      },
                    ),
                  ],

                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Unpin',
                    onPressed: () => _unpin(message),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Desktop/wide-screen inline dropdown panel (Bitrix-style). On
        // mobile/narrow screens the same content opens as a bottom sheet
        // instead (see _onTapList).
        if (_showListPanel)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              child: PinnedMessagesListView(
                pinnedMessages: widget.pinnedMessages,
                onTapMessage: (uid) {
                  setState(() => _showListPanel = false);
                  widget.onTapMessage(uid);
                },
                onUnpin: _unpin,
                onClose: () => setState(() => _showListPanel = false),
              ),
            ),
          ),
      ],
    );
  }
}

/// The full list of pinned messages - "Pinned messages: N" header plus a
/// scrollable list of every pinned message with sender, preview and an
/// unpin action. Shared between the desktop dropdown panel and the mobile
/// bottom sheet.
class PinnedMessagesListView extends StatelessWidget {
  final List<MessagesModel> pinnedMessages;
  final ValueChanged<String> onTapMessage;
  final Future<void> Function(MessagesModel message) onUnpin;
  final VoidCallback onClose;

  const PinnedMessagesListView({
    super.key,
    required this.pinnedMessages,
    required this.onTapMessage,
    required this.onUnpin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Pinned messages: ${pinnedMessages.length}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: pinnedMessages.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 56),
            itemBuilder: (context, index) {
              final message = pinnedMessages[index];
              final senderName = _resolveSenderName(message.senderId);
              final imageUrl = _resolveSenderImageUrl(message.senderId);
              final preview = message.message.isNotEmpty
                  ? message.message
                  : (message.attachments.isNotEmpty ? 'Attachment' : '');

              return ListTile(
                onTap: () {
                  if (message.uid != null) onTapMessage(message.uid!);
                },
                leading: CircleAvatar(
                  backgroundColor: senderName.isNotEmpty
                      ? LetterColors.getColor(senderName[0])
                      : Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            height: 40,
                            width: 40,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Center(
                              child: Text(senderName[0].toUpperCase()),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            senderName.isNotEmpty
                                ? senderName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                ),
                title: Text(
                  senderName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Unpin',
                  onPressed: () => onUnpin(message),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Resolves a sender's display name using the statically-typed
/// `employeeByUid`/`adminByUid` lookups rather than `getUserByUid` (which
/// returns `dynamic`). Dynamic member access on a compiled/release web
/// build can throw a runtime NoSuchMethodError if the compiler renames
/// members it doesn't statically see as dynamically accessed - going
/// through the typed models avoids that entirely.
String _resolveSenderName(String senderId) {
  final employee = CacheService.employeeByUid(senderId);
  if (employee != null) return employee.name;
  final admin = CacheService.adminByUid(senderId);
  if (admin != null) return admin.name;
  return 'User';
}

/// Resolves a sender's avatar URL using the same statically-typed lookups.
String _resolveSenderImageUrl(String senderId) {
  final employee = CacheService.employeeByUid(senderId);
  if (employee != null) return employee.profileImageUrl ?? '';
  final admin = CacheService.adminByUid(senderId);
  if (admin != null) return admin.profileImageUrl ?? '';
  return '';
}
