part of 'chat_messages.dart';

/// One resolved participant of a group chat (name / photo / designation).
class _ChatMemberInfo {
  final String uid;
  final dynamic user; // AdminModel | EmployeeModel | null
  final String name;
  final String? image;
  final String subtitle;
  final bool isOwner;
  final bool isYou;

  const _ChatMemberInfo({
    required this.uid,
    required this.user,
    required this.name,
    required this.image,
    required this.subtitle,
    required this.isOwner,
    required this.isYou,
  });
}

/// "Members: N" panel for a group chat (Bitrix style): close button, search
/// toggle and the list of participants with name + designation.
///
///  • Desktop: shown as a right side panel next to the conversation.
///  • Mobile / narrow: shown inside a bottom sheet ([showAsSheet]).
class ChatMembersPanel extends StatefulWidget {
  final ChatModel chat;
  final String currentUserUid;
  final VoidCallback onClose;

  /// Desktop: switches the chat list to the tapped person's chat.
  final Function(ChatModel chat, String opponentUid)? onOpenChat;

  /// Mobile: context that stays alive after the sheet is closed, used to
  /// push the person's chat screen.
  final BuildContext? navContext;

  /// `true` when rendered inside a bottom sheet (adds a drag handle and
  /// uses rounded top corners instead of a left border).
  final bool isSheet;

  const ChatMembersPanel({
    super.key,
    required this.chat,
    required this.currentUserUid,
    required this.onClose,
    this.onOpenChat,
    this.navContext,
    this.isSheet = false,
  });

  /// Mobile presentation: modal bottom sheet that also moves above the
  /// keyboard while searching.
  static void showAsSheet(
    BuildContext context, {
    required ChatModel chat,
    required String currentUserUid,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SizedBox(
            height: (mq.size.height * 0.8).clamp(320.0, mq.size.height),
            child: ChatMembersPanel(
              chat: chat,
              currentUserUid: currentUserUid,
              isSheet: true,
              navContext: context,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
    );
  }

  @override
  State<ChatMembersPanel> createState() => _ChatMembersPanelState();
}

class _ChatMembersPanelState extends State<ChatMembersPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ChatMemberInfo> _resolveMembers() {
    final members = <_ChatMemberInfo>[];
    final seen = <String>{};

    for (final uid in widget.chat.participants) {
      if (uid.isEmpty || !seen.add(uid)) continue;
      final user = CacheService.getUserByUid(uid);

      String name = 'Unknown user';
      String? image;
      String subtitle = '';

      if (user is AdminModel) {
        name = user.name;
        image = user.profileImageUrl;
        subtitle = 'Admin';
      } else if (user is EmployeeModel) {
        name = user.name;
        image = user.profileImageUrl;
        subtitle =
            CacheService.designationByUid(user.designation)?.name ?? 'Employee';
      }

      members.add(
        _ChatMemberInfo(
          uid: uid,
          user: user,
          name: name,
          image: image,
          subtitle: subtitle,
          isOwner: uid == widget.chat.createdBy,
          isYou: uid == widget.currentUserUid,
        ),
      );
    }

    // Group owner first, then alphabetical.
    members.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return members;
  }

  /// Opens (or creates) the 1-to-1 chat with the tapped member.
  Future<void> _openMemberChat(_ChatMemberInfo m) async {
    // Tapping yourself just shows your profile (no chat with yourself here).
    if (m.isYou) {
      if (m.user != null) openUser(context, m.user);
      return;
    }
    try {
      final cid = await Spdb.getCid();
      String? chatId = await ChatService.getChatUid(m.uid);
      chatId ??= await ChatService.createIndividualChat(userId: m.uid);

      final doc = await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .doc(chatId)
          .get();
      if (!doc.exists) return;
      final chat = ChatModel.fromMap(doc.id, doc.data()!);

      if (widget.isSheet) {
        // Mobile: close the sheet, then open the person's chat screen.
        final nav = widget.navContext;
        widget.onClose();
        if (nav != null && nav.mounted) {
          Navigate.route(
            nav,
            ChatMessages(
              chat: chat,
              currentUser: widget.currentUserUid,
              opponentUid: m.uid,
            ),
          );
        }
        return;
      }

      if (widget.onOpenChat != null) {
        // Desktop: swap the right pane to that person's chat.
        widget.onOpenChat!(chat, m.uid);
      } else if (mounted) {
        Navigate.route(
          context,
          ChatMessages(
            chat: chat,
            currentUser: widget.currentUserUid,
            opponentUid: m.uid,
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(
        context,
        'Failed to open chat',
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _controller.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final all = _resolveMembers();
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
              .where(
                (m) =>
                    m.name.toLowerCase().contains(q) ||
                    m.subtitle.toLowerCase().contains(q),
              )
              .toList();

    final content = Column(
      children: [
        if (widget.isSheet)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        _buildHeader(context, all.length),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No members found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _buildTile(context, shown[i]),
                ),
        ),
      ],
    );

    return Material(
      color: cs.surface,
      shape: widget.isSheet
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            )
          : Border(left: BorderSide(color: cs.outlineVariant, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildHeader(BuildContext context, int total) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _searching
            ? Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Iconsax.search_normal, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search members...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close search',
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: _toggleSearch,
                  ),
                ],
              )
            : Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: widget.onClose,
                  ),
                  Expanded(
                    child: Text(
                      'Members: $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search members',
                    icon: Icon(Iconsax.search_normal, color: cs.primary),
                    onPressed: _toggleSearch,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _ChatMemberInfo m) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => _openMemberChat(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildAvatar(m),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.isYou ? '${m.name} (You)' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (m.subtitle.isNotEmpty)
                    Text(
                      m.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (m.isOwner)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Owner',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(_ChatMemberInfo m) {
    final hasImage = m.image != null && m.image!.isNotEmpty;
    final initial = m.name.isNotEmpty ? m.name[0].toUpperCase() : '?';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: hasImage ? null : LetterColors.getColor(initial),
        shape: BoxShape.circle,
      ),
      child: hasImage
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: m.image!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                // Broken photo -> fall back to the initial, never a blank.
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }
}