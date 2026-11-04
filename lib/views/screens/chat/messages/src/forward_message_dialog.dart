part of 'chat_messages.dart';

/// One place a message can be forwarded to: an existing chat (group or
/// 1-to-1) or a colleague you have no chat with yet (the chat is created
/// when forwarding).
class _ForwardTarget {
  final String key; // 'chat:<id>' | 'user:<uid>'
  final String? chatId;
  final String? userId;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isGroup;

  const _ForwardTarget({
    required this.key,
    required this.title,
    required this.subtitle,
    this.chatId,
    this.userId,
    this.imageUrl,
    this.isGroup = false,
  });
}

/// "Forward Message" picker.
///
/// Follows the same pattern as the other panels of the app (e.g. the
/// "New Conversation" sheet): opened with [Sheet.showSheet], brand-gradient
/// header, card sections, gradient primary button, theme fonts/colors.
///
///  • Works for every kind of message: text, image, video, audio, voice
///    note and documents (attachments are re-used, no re-upload).
///  • Multi-select chats and people, search, one "Forward" button.
class ForwardMessageDialog extends StatefulWidget {
  final MessagesModel message;
  final String sourceChatId;
  final String currentUserUid;
  final BuildContext hostContext;

  const ForwardMessageDialog({
    super.key,
    required this.message,
    required this.sourceChatId,
    required this.currentUserUid,
    required this.hostContext,
  });

  static Future<void> show(
    BuildContext context, {
    required MessagesModel message,
    required String sourceChatId,
    required String currentUserUid,
  }) async {
    await Sheet.showSheet(
      context,
      size: 0.9,
      widget: ForwardMessageDialog(
        message: message,
        sourceChatId: sourceChatId,
        currentUserUid: currentUserUid,
        hostContext: context,
      ),
    );
  }

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  // Same brand gradient as the other panels (e.g. CreateChat).
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};

  List<_ForwardTarget> _chatTargets = [];
  List<_ForwardTarget> _peopleTargets = [];
  bool _loading = true;
  bool _sending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── data ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final cid = await Spdb.getCid();
      final me = widget.currentUserUid;

      final snap = await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .where('participants', arrayContains: me)
          .get();

      final chats = snap.docs
          .map((d) => ChatModel.fromMap(d.id, d.data()))
          .toList()
        ..sort(
          (a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
            a.updatedAt?.millisecondsSinceEpoch ?? 0,
          ),
        );

      final usersWithChat = <String>{};
      final chatTargets = <_ForwardTarget>[];

      for (final chat in chats) {
        final id = chat.uid;
        if (id == null) continue;

        if (chat.isGroupChat) {
          chatTargets.add(
            _ForwardTarget(
              key: 'chat:$id',
              chatId: id,
              title: chat.title ?? 'Group',
              subtitle: '${chat.participants.length} members',
              isGroup: true,
            ),
          );
        } else {
          final opponent = chat.participants.firstWhere(
            (p) => p != me,
            orElse: () => '',
          );
          if (opponent.isEmpty) continue; // chat with yourself
          usersWithChat.add(opponent);

          final info = _personInfo(opponent);
          if (info == null) continue; // user no longer exists
          chatTargets.add(
            _ForwardTarget(
              key: 'chat:$id',
              chatId: id,
              title: info.$1,
              subtitle: info.$2,
              imageUrl: info.$3,
            ),
          );
        }
      }

      // Colleagues you never chatted with: the chat is created on forward.
      final people = <_ForwardTarget>[];
      final seen = <String>{me, ...usersWithChat};

      for (final e in CacheService().getAllListenableEmployees().value) {
        final id = e.uid ?? '';
        if (id.isEmpty || !e.isActive || !seen.add(id)) continue;
        people.add(
          _ForwardTarget(
            key: 'user:$id',
            userId: id,
            title: e.name,
            subtitle:
                CacheService.designationByUid(e.designation)?.name ??
                'Employee',
            imageUrl: e.profileImageUrl,
          ),
        );
      }
      try {
        for (final a in await AdminService.getAllAdmins()) {
          final id = a.uid ?? '';
          if (id.isEmpty || !seen.add(id)) continue;
          people.add(
            _ForwardTarget(
              key: 'user:$id',
              userId: id,
              title: a.name,
              subtitle: 'Admin',
              imageUrl: a.profileImageUrl,
            ),
          );
        }
      } catch (_) {
        // Admin list is optional; employees + chats are enough.
      }
      people.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _chatTargets = chatTargets;
        _peopleTargets = people;
        _loading = false;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  /// (name, subtitle, imageUrl) of a user, or null if unknown.
  (String, String, String?)? _personInfo(String uid) {
    final emp = CacheService.employeeByUid(uid);
    if (emp != null) {
      return (
        emp.name,
        CacheService.designationByUid(emp.designation)?.name ?? 'Employee',
        emp.profileImageUrl,
      );
    }
    final admin = CacheService.adminByUid(uid);
    if (admin != null) return (admin.name, 'Admin', admin.profileImageUrl);
    return null;
  }

  // ── actions ─────────────────────────────────────────────────────────────

  Future<void> _forward() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);

    final all = [..._chatTargets, ..._peopleTargets];
    final chosen = all.where((t) => _selected.contains(t.key)).toList();
    final chatIds = [
      for (final t in chosen)
        if (t.chatId != null) t.chatId!,
    ];
    final userIds = [
      for (final t in chosen)
        if (t.userId != null) t.userId!,
    ];

    final host = widget.hostContext;
    try {
      final ok = await ChatService.forwardMessage(
        source: widget.message,
        sourceChatId: widget.sourceChatId,
        targetChatIds: chatIds,
        targetUserIds: userIds,
      );
      if (mounted) Navigator.pop(context);
      if (host.mounted) {
        FlushBar.show(
          host,
          ok == chosen.length
              ? 'Message forwarded'
              : 'Forwarded to $ok of ${chosen.length} chats',
          isSuccess: ok > 0,
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) setState(() => _sending = false);
      if (host.mounted) {
        FlushBar.show(
          host,
          'Could not forward message',
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void _toggle(_ForwardTarget t) {
    if (_sending) return;
    setState(() {
      if (!_selected.add(t.key)) _selected.remove(t.key);
    });
  }

  // ── preview text of the message being forwarded ─────────────────────────

  IconData get _previewIcon {
    final files = widget.message.attachments;
    if (files.isEmpty) return Iconsax.message_text;
    final f = files.first;
    if (f.isVoice) return Iconsax.microphone_2;
    if (f.mimeType.startsWith('image')) return Iconsax.gallery;
    if (f.mimeType.startsWith('video')) return Iconsax.video;
    if (f.mimeType.startsWith('audio')) return Iconsax.music;
    return Iconsax.document_text;
  }

  String get _previewText {
    final m = widget.message;
    final files = m.attachments;
    String label = '';
    if (files.isNotEmpty) {
      final f = files.first;
      if (f.isVoice) {
        label = 'Voice message';
      } else if (f.mimeType.startsWith('image')) {
        label = 'Photo';
      } else if (f.mimeType.startsWith('video')) {
        label = 'Video';
      } else if (f.mimeType.startsWith('audio')) {
        label = 'Audio';
      } else {
        label = f.name.isNotEmpty ? f.name : 'Document';
      }
      if (files.length > 1) label = '$label +${files.length - 1} more';
    }
    if (m.message.trim().isEmpty) return label;
    return label.isEmpty ? m.message : '${m.message}\n[$label]';
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  bool _matches(_ForwardTarget t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.subtitle.toLowerCase().contains(q);
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Iconsax.send_2,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Forward Message",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Choose chats or people to send this message to",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: AppColors.white),
            onPressed: _sending ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_previewIcon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Message",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search chats or people',
        prefixIcon: const Icon(Iconsax.search_normal, size: 18),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    final theme = Theme.of(context);
    final bool enabled = _selected.isNotEmpty && !_sending;
    final String label = _sending
        ? 'Forwarding...'
        : _selected.isEmpty
        ? 'Forward'
        : 'Forward to ${_selected.length} ${_selected.length == 1 ? 'chat' : 'chats'}';

    return Opacity(
      opacity: enabled || _sending ? 1 : 0.5,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _brandGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4364F7).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? _forward : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Iconsax.send_2, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final chats = _chatTargets.where(_matches).toList();
    final people = _peopleTargets.where(_matches).toList();

    final rows = <Object>[
      if (chats.isNotEmpty) 'Recent chats',
      ...chats,
      if (people.isNotEmpty) 'People',
      ...people,
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  _buildPreviewCard(context),
                  const SizedBox(height: 12),
                  _buildSearchField(context),
                ],
              ),
            ),
            // List of chats / people
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                clipBehavior: Clip.antiAlias,
                decoration: _cardDecoration(context),
                child: _loading
                    ? const WaitingLoading()
                    : rows.isEmpty
                    ? Center(
                        child: Text(
                          'No chats or people found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          if (row is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                              child: Text(
                                row,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }
                          return _buildRow(context, row as _ForwardTarget);
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildPrimaryButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _ForwardTarget t) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = _selected.contains(t.key);

    return InkWell(
      onTap: () => _toggle(t),
      child: Container(
        color: selected ? cs.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildAvatar(t),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (t.subtitle.isNotEmpty)
                    Text(
                      t.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ModernCheckbox(value: selected, onChanged: (_) => _toggle(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(_ForwardTarget t) {
    final hasImage = t.imageUrl != null && t.imageUrl!.isNotEmpty;
    final initial = t.title.isNotEmpty ? t.title[0].toUpperCase() : '?';

    if (t.isGroup) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Iconsax.people, size: 20, color: Colors.white),
      );
    }
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
                imageUrl: t.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
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