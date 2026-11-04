part of 'chat_messages.dart';

// ─────────────────────────────────────────────────────────────────
// "Who reacted" (Bitrix-style)
// ─────────────────────────────────────────────────────────────────
//
// * Desktop / web with a mouse (Windows, macOS, Linux, web):
//     - hover a reaction chip  -> small popup listing everyone who
//       reacted with that emoji (avatar + name)
//     - click a reaction chip  -> toggles your own reaction (unchanged)
// * Touch devices (Android, iOS, mobile web):
//     - tap a reaction chip    -> bottom sheet with an "All" tab plus one
//       tab per emoji; your own entry can be tapped to remove it
//
// Data comes from the existing `reactions` map on [MessagesModel]
// (`emoji -> [userId, ...]`), so no Firestore schema change is needed.
// Names / avatars reuse [_resolveSenderName] / [_resolveSenderImageUrl].

/// True on devices where hover does not exist (phones / tablets, including
/// mobile browsers). Those get the bottom sheet instead of the hover popup.
bool _useTouchReactionUi() {
  if (kIsMobile) return true;
  return kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

class _ReactionEntry {
  final String uid;
  final String emoji;
  const _ReactionEntry(this.uid, this.emoji);
}

/// Flattens `emoji -> [uids]` into a de-duplicated list of (uid, emoji).
List<_ReactionEntry> _flattenReactions(
  Map<String, List<String>> reactions, {
  String? onlyEmoji,
}) {
  final out = <_ReactionEntry>[];
  final seen = <String>{};
  for (final e in reactions.entries) {
    if (onlyEmoji != null && e.key != onlyEmoji) continue;
    for (final uid in e.value) {
      if (seen.add('${e.key}|$uid')) out.add(_ReactionEntry(uid, e.key));
    }
  }
  return out;
}

String _reactionUserName(String uid, String? currentUserId) =>
    uid == currentUserId ? 'You' : _resolveSenderName(uid);

class _ReactionUserAvatar extends StatelessWidget {
  final String uid;
  final double radius;
  const _ReactionUserAvatar({required this.uid, required this.radius});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pic = _resolveSenderImageUrl(uid);
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
      child: pic.isEmpty
          ? Icon(Icons.person, size: radius * 0.9, color: cs.outline)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Single reaction chip (with desktop hover popup)
// ─────────────────────────────────────────────────────────────────

class _ReactionChip extends StatefulWidget {
  final String emoji;
  final List<String> users;
  final bool isSender;
  final String? currentUserId;
  final VoidCallback? onTap;

  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.users,
    required this.isSender,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _showAbove = false;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _requestShow() {
    _hideTimer?.cancel();
    if (_overlayController.isShowing) return;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Open below the chip when there is room, otherwise above it
      // (messages at the very bottom sit right on top of the composer).
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        final screenHeight = MediaQuery.sizeOf(context).height;
        _showAbove = screenHeight - bottom < 320;
      }
      setState(() {});
      _overlayController.show();
    });
  }

  void _requestHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_overlayController.isShowing) _overlayController.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reactedByMe =
        widget.currentUserId != null &&
        widget.users.contains(widget.currentUserId);
    final count = widget.users.length;
    final isSender = widget.isSender;
    final above = _showAbove;

    final chip = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: reactedByMe
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reactedByMe
                ? cs.primary.withValues(alpha: 0.6)
                : (theme.cardTheme.color ?? cs.surface),
            width: 2,
          ),
        ),
        child: Text(
          '${widget.emoji} ${count > 1 ? count : ''}',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );

    // Touch devices: no hover, the parent opens the bottom sheet on tap.
    if (_useTouchReactionUi()) return chip;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (BuildContext context) {
          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: above
                ? (isSender ? Alignment.topRight : Alignment.topLeft)
                : (isSender ? Alignment.bottomRight : Alignment.bottomLeft),
            followerAnchor: above
                ? (isSender ? Alignment.bottomRight : Alignment.bottomLeft)
                : (isSender ? Alignment.topRight : Alignment.topLeft),
            offset: Offset(0, above ? -4 : 4),
            child: Align(
              alignment: above
                  ? (isSender ? Alignment.bottomRight : Alignment.bottomLeft)
                  : (isSender ? Alignment.topRight : Alignment.topLeft),
              child: MouseRegion(
                onEnter: (_) => _hideTimer?.cancel(),
                onExit: (_) => _requestHide(),
                child: _ReactionUsersPopup(
                  emoji: widget.emoji,
                  users: widget.users,
                  currentUserId: widget.currentUserId,
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _requestShow(),
          onExit: (_) => _requestHide(),
          child: chip,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Desktop hover popup
// ─────────────────────────────────────────────────────────────────

class _ReactionUsersPopup extends StatelessWidget {
  final String emoji;
  final List<String> users;
  final String? currentUserId;

  const _ReactionUsersPopup({
    required this.emoji,
    required this.users,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxWidth = (MediaQuery.sizeOf(context).width - 24).clamp(
      160.0,
      260.0,
    );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 300),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '${users.length} ${users.length == 1 ? 'reaction' : 'reactions'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final uid = users[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        _ReactionUserAvatar(uid: uid, radius: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _reactionUserName(uid, currentUserId),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Touch bottom sheet
// ─────────────────────────────────────────────────────────────────

/// Opens the "who reacted" bottom sheet. [onRemoveOwn] is invoked with the
/// emoji when the current user taps their own entry to remove it.
void _showReactionUsersSheet(
  BuildContext context, {
  required Map<String, List<String>> reactions,
  required String? currentUserId,
  required String initialEmoji,
  required ValueChanged<String> onRemoveOwn,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Keeps the sheet a sensible width on tablets / wide mobile browsers.
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ReactionUsersSheet(
      reactions: reactions,
      currentUserId: currentUserId,
      initialEmoji: initialEmoji,
      onRemoveOwn: onRemoveOwn,
    ),
  );
}

class _ReactionUsersSheet extends StatefulWidget {
  final Map<String, List<String>> reactions;
  final String? currentUserId;
  final String initialEmoji;
  final ValueChanged<String> onRemoveOwn;

  const _ReactionUsersSheet({
    required this.reactions,
    required this.currentUserId,
    required this.initialEmoji,
    required this.onRemoveOwn,
  });

  @override
  State<_ReactionUsersSheet> createState() => _ReactionUsersSheetState();
}

class _ReactionUsersSheetState extends State<_ReactionUsersSheet> {
  /// Selected emoji tab; null means the "All" tab.
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialEmoji;
  }

  Widget _tab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final tabs = widget.reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    // If the selected emoji no longer exists, fall back to "All".
    final selected = tabs.any((e) => e.key == _selected) ? _selected : null;
    final total = _flattenReactions(widget.reactions).length;
    final entries = _flattenReactions(widget.reactions, onlyEmoji: selected);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _tab(
                      label: 'All $total',
                      selected: selected == null,
                      onTap: () => setState(() => _selected = null),
                    ),
                    for (final e in tabs)
                      _tab(
                        label: '${e.key} ${e.value.length}',
                        selected: selected == e.key,
                        onTap: () => setState(() => _selected = e.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isMe = entry.uid == widget.currentUserId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      leading: _ReactionUserAvatar(uid: entry.uid, radius: 20),
                      title: Text(
                        _reactionUserName(entry.uid, widget.currentUserId),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: isMe
                          ? Text(
                              'Tap to remove',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.outline,
                              ),
                            )
                          : null,
                      trailing: Text(
                        entry.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      onTap: isMe
                          ? () {
                              Navigator.of(context).pop();
                              widget.onRemoveOwn(entry.emoji);
                            }
                          : null,
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}
