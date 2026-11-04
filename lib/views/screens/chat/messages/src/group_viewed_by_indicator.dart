part of 'chat_messages.dart';

// ─────────────────────────────────────────────────────────────────
// Group Chat "Viewed By" Indicator (Bitrix-style, conversation-level)
// ─────────────────────────────────────────────────────────────────

/// A single, conversation-level "Viewed by" indicator for **group chats**.
///
/// Bitrix-style behaviour: instead of showing "Viewed by ..." underneath
/// every outgoing message, this widget is rendered exactly **once**, at
/// the bottom of the whole message list, and always reflects the viewers
/// of the latest outgoing message sent by the current user.
///
/// * Reuses the existing `seenBy` field on [MessagesModel] — no new
///   Firestore schema/collections are introduced.
/// * Reuses the existing [_resolveSenderName] / [_resolveSenderImageUrl]
///   helpers (defined in `pinned_messages_bar.dart`, part of this same
///   library) for user lookups — no duplicate user-fetching logic.
/// * This widget owns its own popup ([_GroupViewedByPopup], desktop hover)
///   and bottom sheet ([_GroupViewedBySheet], tap/mobile) so it has no
///   dependency on `chat_bubble.dart` internals.
/// * The sender is always excluded from the displayed viewer list/count.
/// * Renders nothing when the current user hasn't sent a message yet, or
///   when nobody (other than the sender) has viewed the latest one.
class GroupViewedByIndicator extends StatefulWidget {
  /// The latest message sent by the current user in this chat. Null when
  /// the current user hasn't sent any message yet.
  final MessagesModel? latestOutgoingMessage;

  /// UID of the currently signed-in user (the sender), used to exclude
  /// them from the viewer list/count.
  final String currentUser;

  /// Current group membership, used to defensively filter out any
  /// `seenBy` entries that no longer belong to the group (e.g. a member
  /// who has since left).
  final List<String> participants;

  const GroupViewedByIndicator({
    super.key,
    required this.latestOutgoingMessage,
    required this.currentUser,
    required this.participants,
  });

  @override
  State<GroupViewedByIndicator> createState() =>
      _GroupViewedByIndicatorState();
}

class _GroupViewedByIndicatorState extends State<GroupViewedByIndicator> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  /// Viewers of [GroupViewedByIndicator.latestOutgoingMessage], with the
  /// sender excluded, de-duplicated, and (when membership data is
  /// available) restricted to current group members.
  List<String> get _viewers {
    final message = widget.latestOutgoingMessage;
    if (message == null || message.seenBy.isEmpty) return const [];

    final participantSet = widget.participants.toSet();
    final seen = <String>{};
    final viewers = <String>[];

    for (final uid in message.seenBy) {
      if (uid == widget.currentUser) continue; // never count the sender
      if (participantSet.isNotEmpty && !participantSet.contains(uid)) {
        continue; // skip users who are no longer group members
      }
      if (seen.add(uid)) viewers.add(uid);
    }
    return viewers;
  }

  void _showSeenBySheet(BuildContext context, List<String> viewers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupViewedBySheet(seenBy: viewers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewers = _viewers;

    // Nothing to show yet: no outgoing message, or nobody has viewed it.
    if (widget.latestOutgoingMessage == null || viewers.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final firstViewerName = _resolveSenderName(viewers.first);
    final remainingCount = viewers.length - 1;

    final label = remainingCount > 0
        ? 'Viewed by $firstViewerName and $remainingCount more'
        : 'Viewed by $firstViewerName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: (BuildContext context) {
              // The overlay hands its child TIGHT, screen-sized
              // constraints. The outer top-left `Align` loosens them so
              // the follower (and the popup inside it) is sized by its own
              // content instead of stretching across the whole screen.
              // The follower's position comes from the layer link, not
              // from where it sits inside this `Align`.
              return Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  // Popup's bottom-right sits on the indicator's top-right
                  // (the indicator is just above the composer, so there is
                  // no room below).
                  targetAnchor: Alignment.topRight,
                  followerAnchor: Alignment.bottomRight,
                  child: MouseRegion(
                    onEnter: (_) => _overlayController.show(),
                    onExit: (_) => _overlayController.hide(),
                    // Gap is padding INSIDE the MouseRegion so the pointer
                    // can move from the label to the popup without it
                    // closing.
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _GroupViewedByPopup(seenBy: viewers),
                    ),
                  ),
                ),
              );
            },
            child: MouseRegion(
              onEnter: (_) {
                if (!kIsMobile) _overlayController.show();
              },
              onExit: (_) {
                if (!kIsMobile) _overlayController.hide();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showSeenBySheet(context, viewers),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all, size: 13, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Desktop hover popup
// ─────────────────────────────────────────────────────────────────

/// A compact popup that shows the list of viewers on hover (desktop only).
class _GroupViewedByPopup extends StatelessWidget {
  final List<String> seenBy;

  const _GroupViewedByPopup({required this.seenBy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 300),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.done_all, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Viewed by ${seenBy.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Viewer list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: seenBy.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final uid = seenBy[index];
                final name = _resolveSenderName(uid);
                final pic = _resolveSenderImageUrl(uid);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.surfaceContainerHighest,
                        backgroundImage: pic.isNotEmpty
                            ? CachedNetworkImageProvider(pic)
                            : null,
                        child: pic.isEmpty
                            ? Icon(Icons.person, size: 14, color: cs.outline)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.done_all, size: 12, color: cs.primary),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Mobile / tap bottom sheet
// ─────────────────────────────────────────────────────────────────

/// A modal bottom sheet that lists every group member who has viewed the
/// latest outgoing message.
class _GroupViewedBySheet extends StatelessWidget {
  final List<String> seenBy;

  const _GroupViewedBySheet({required this.seenBy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // ── Header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Viewed by ${seenBy.length} '
                      'member${seenBy.length == 1 ? '' : 's'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),

              // ── Member list ──────────────────────────────────────
              Flexible(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  itemCount: seenBy.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final uid = seenBy[index];
                    final name = _resolveSenderName(uid);
                    final pic = _resolveSenderImageUrl(uid);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.surfaceContainerHighest,
                        backgroundImage: pic.isNotEmpty
                            ? CachedNetworkImageProvider(pic)
                            : null,
                        child: pic.isEmpty
                            ? Icon(Icons.person, size: 18, color: cs.outline)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done_all, size: 13, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Seen',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom safe area ─────────────────────────────────
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}