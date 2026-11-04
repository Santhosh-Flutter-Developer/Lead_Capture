part of 'chat_messages.dart';

void openUser(BuildContext context, dynamic user) {
  final width = MediaQuery.of(context).size.width;
  if (user == null) return;

  if (kIsMobile || width < 1000) {
    Sheet.showSheet(
      context,
      widget: user is AdminModel
          ? AdminProfile(admin: user)
          : EmployeeDetails(employee: user),
    );
  } else {
    GeneralDialog.showRTLSheet(
      context,
      user is AdminModel
          ? AdminProfile(admin: user)
          : EmployeeDetails(employee: user),
    );
  }
}

class ChatTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String userUid;
  final String currentUserUid;
  final String lastSeen;
  final VoidCallback? onBack;
  final ChatModel chat;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClose;
  final bool isSearching;

  const ChatTopBar({
    super.key,
    required this.userUid,
    required this.currentUserUid,
    required this.lastSeen,
    this.onBack,
    required this.chat,
    this.onSearchChanged,
    this.onSearchClose,
    this.isSearching = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final bool isSelfChat =
        userUid == currentUserUid ||
        userUid.isEmpty ||
        chat.participants.every((id) => id == currentUserUid);
    final dynamic user = isSelfChat ? null : CacheService.getUserByUid(userUid);

    String? userName;
    String? userImage;

    if (isSelfChat) {
      userName = "Saved Messages";
      userImage = null; // We'll use a special icon below
    } else if (user is AdminModel) {
      userName = user.name;
      userImage = user.profileImageUrl;
    } else if (user is EmployeeModel) {
      userName = user.name;
      userImage = user.profileImageUrl;
    } else {
      userName = null;
      userImage = null;
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
          ),
        ),
      ),
      elevation: 2,
      titleSpacing: 0,
      title: isSearching
          ? _buildSearchField()
          : Row(
              children: [
                if (onBack != null)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: onBack,
                  ),
                if (chat.isGroupChat) ...[
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    radius: 22,
                    child: Icon(Icons.group, size: 20),
                  ),
                ] else ...[
                  if (isSelfChat) ...[
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      radius: 20,
                      child: Icon(
                        Iconsax.save_2,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ] else if (userImage != null && userImage.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => openUser(context, user),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: CachedNetworkImage(
                          imageUrl: userImage,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Theme.of(context).dividerColor,
                            highlightColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            child: Container(
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          height: 35,
                          width: 35,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => openUser(context, user),
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        radius: 22,
                        child: Text(
                          (userName ?? '?').capitalizeFirst,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: chat.isGroupChat
                        // Group: show the members list (with search).
                        ? () => ChatMembersPanel.showAsSheet(
                            context,
                            chat: chat,
                            currentUserUid: currentUserUid,
                          )
                        : isSelfChat
                        ? null
                        : () => openUser(context, user),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (chat.isGroupChat) ...[
                          Text(
                            chat.title ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chat.participants.length} Members',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.grey200),
                          ),
                        ] else ...[
                          Text(
                            userName ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                          ),
                          const SizedBox(height: 2),
                          if (isSelfChat)
                            Text(
                              "Chat with yourself",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.grey200),
                            )
                          else
                            StreamBuilder<UserStatusModel?>(
                              stream: UserStatusService.streamStatus(userUid),
                              builder: (context, snapshot) {
                                if (userUid.isEmpty) {
                                  return Text(
                                    "Last seen: Unknown",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.grey200),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return Text(
                                    "Last seen: loading...",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.grey200),
                                  );
                                }

                                final status = snapshot.data!;

                                return Text(
                                  status.isOnline
                                      ? "Online"
                                      : "Last seen: ${formatLastSeen(status.lastSeen)}",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.grey200),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(
            isSearching ? Icons.close : Iconsax.search_normal,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            if (isSearching) {
              onSearchClose?.call();
            } else {
              onSearchChanged?.call('');
            }
          },
        ),

        if (!isSearching)
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => AboutChat(
                  chat: chat,
                  userUid: userUid,
                  currentUserUid: currentUserUid,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 220, // adjust width here
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            autofocus: true,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(
                color: AppColors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              icon: Icon(
                Iconsax.search_normal,
                size: 18,
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatTopBarDesktop extends StatelessWidget implements PreferredSizeWidget {
  final String userUid;
  final String currentUserUid;
  final String lastSeen;
  final VoidCallback? onBack;
  final ChatModel chat;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClose;
  final bool isSearching;

  /// Toggles the "Members" side panel (group chats).
  final VoidCallback? onMembersTap;
  final bool isMembersOpen;

  const ChatTopBarDesktop({
    super.key,
    required this.userUid,
    required this.currentUserUid,
    required this.lastSeen,
    this.onBack,
    required this.chat,
    this.onSearchChanged,
    this.onSearchClose,
    this.isSearching = false,
    this.onMembersTap,
    this.isMembersOpen = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final bool isSelfChat =
        userUid == currentUserUid ||
        userUid.isEmpty ||
        chat.participants.every((id) => id == currentUserUid);
    final dynamic user = isSelfChat ? null : CacheService.getUserByUid(userUid);

    String? userName;
    String? userImage;

    if (isSelfChat) {
      userName = "Saved Messages";
      userImage = null;
    } else if (user is AdminModel) {
      userName = user.name;
      userImage = user.profileImageUrl;
    } else if (user is EmployeeModel) {
      userName = user.name;
      userImage = user.profileImageUrl;
    } else {
      userName = null;
      userImage = null;
    }

    return AppBar(
      centerTitle: false,
      shape: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      toolbarHeight: 56,
      leadingWidth: 48,
      titleSpacing: 0,

      leading: isSearching
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildLeadingAvatar(
                context,
                user,
                userName,
                userImage,
                isSelfChat,
              ),
            ),

      title: isSearching
          ? _buildSearchField(context)
          : _buildTitle(context, user, userName, userImage, isSelfChat),

      actions: [
        IconButton(
          icon: Icon(
            isSearching ? Icons.close : Iconsax.search_normal,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            if (isSearching) {
              onSearchClose?.call();
            } else {
              onSearchChanged?.call('');
            }
          },
        ),

        if (!isSearching)
          IconButton(
            icon: Icon(
              Iconsax.info_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              GeneralDialog.showRTLSheet(
                context,
                AboutChat(
                  chat: chat,
                  userUid: userUid,
                  currentUserUid: currentUserUid,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLeadingAvatar(
    BuildContext context,
    dynamic user,
    String? userName,
    String? userImage,
    bool isSelfChat,
  ) {
    if (chat.isGroupChat) {
      return CircleAvatar(
        radius: 15,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.group,
          size: 18,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }

    if (isSelfChat) {
      return CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.primary,
        child: Icon(
          Iconsax.save_2,
          size: 18,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }

    if (userImage != null && userImage.isNotEmpty) {
      return GestureDetector(
        onTap: () => openUser(context, user),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: CachedNetworkImage(
            imageUrl: userImage,
            height: 32,
            width: 32,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => openUser(context, user),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: LetterColors.getColor((userName ?? '?').first),
        child: Text(
          (userName ?? '?').first,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    dynamic user,
    String? userName,
    String? userImage,
    bool isSelfChat,
  ) {
    if (isSearching) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: chat.isGroupChat
                ? MouseRegion(
                    cursor: onMembersTap != null
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onMembersTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${chat.participants.length} Members',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isMembersOpen
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: isSelfChat ? null : () => openUser(context, user),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (isSelfChat)
                          Text(
                            "Chat with yourself",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.grey500),
                          )
                        else
                          StreamBuilder<UserStatusModel?>(
                            stream: UserStatusService.streamStatus(userUid),
                            builder: (context, snapshot) {
                              if (userUid.isEmpty) {
                                return Text(
                                  "Last seen: ",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.grey500),
                                );
                              }
                              if (!snapshot.hasData) {
                                return Text(
                                  "",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.grey500),
                                );
                              }
                              final status = snapshot.data!;
                              return Text(
                                status.isOnline
                                    ? "Online"
                                    : "Last seen: ${formatLastSeen(status.lastSeen)}",
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.grey500),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grey300),
      ),
      child: TextField(
        autofocus: true,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          icon: const Icon(Iconsax.search_normal, size: 18),
        ),
      ),
    );
  }
}

String formatLastSeen(DateTime? time) {
  if (time == null) return "Unknown";

  final now = DateTime.now();
  final diff = now.difference(time);

  String formatTime12(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  if (diff.inMinutes < 1) {
    return "Just now";
  } else if (diff.inMinutes < 60) {
    return "${diff.inMinutes} min ago";
  } else if (diff.inHours < 24) {
    return "${diff.inHours} hours ago";
  } else if (diff.inDays == 1) {
    return "Yesterday, ${formatTime12(time)}";
  } else {
    return "${time.day}-${time.month}-${time.year}, ${formatTime12(time)}";
  }
}