import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import 'bloc/chat_bloc.dart';

const String _pageTitle = "Chat";

class ChatListing extends StatelessWidget {
  final String currentUserUid;
  final String? selectedChatUid;
  const ChatListing({
    super.key,
    required this.currentUserUid,
    this.selectedChatUid,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc()..add(StreamChat()),
      child: ChatListingView(
        currentUserUid: currentUserUid,
        selectedChatUid: selectedChatUid,
      ),
    );
  }
}

class ChatListingView extends StatefulWidget {
  final String currentUserUid;
  final String? selectedChatUid;

  const ChatListingView({
    super.key,
    required this.currentUserUid,
    this.selectedChatUid,
  });

  @override
  State<ChatListingView> createState() => _ChatListingViewState();
}

class _ChatListingViewState extends State<ChatListingView> {
  String? _selectedChatUid;
  String? _pendingOpponentUid;

  @override
  void initState() {
    _selectedChatUid = widget.selectedChatUid;
    debugPrint("the chat id on the listing inside $_selectedChatUid");
    super.initState();
  }

  void _openChatFromMention(ChatModel chat, String opponentUid) {
    setState(() {
      _selectedChatUid = chat.uid;
      _pendingOpponentUid = null;
    });
  }

  Future<void> _refreshChats(BuildContext context) async {
    context.read<ChatBloc>().add(StreamChat());
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: kIsMobile || width < 1000
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const WaitingLoading();
          } else if (state is ChatLoaded) {
            final selectedIndex = state.chats.indexWhere(
              (c) => c.uid == _selectedChatUid,
            );
            // The chat stream filters out conversations that don't have a
            // lastMessage yet (see ChatBloc._streamChat), which is exactly
            // the state of a chat right after it's created via "start new
            // chat" and before either side has sent a message. Without this
            // fallback, _selectedChatUid points at a chat the stream will
            // never surface, so the message pane stays stuck on "Select a
            // Conversation" no matter how long you wait.
            final selectedChat = selectedIndex != -1
                ? state.chats[selectedIndex]
                : (_selectedChatUid != null && _pendingOpponentUid != null
                      ? ChatModel(
                          uid: _selectedChatUid,
                          createdBy: widget.currentUserUid,
                          participants: [
                            widget.currentUserUid,
                            _pendingOpponentUid!,
                          ],
                          participantsKey:
                              ([widget.currentUserUid, _pendingOpponentUid!]
                                    ..sort())
                                  .join('_'),
                          isPinned: false,
                          isFavorite: false,
                          lastMessage: null,
                        )
                      : null);
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1000) {
                  if (state.chats.isNotEmpty) {
                    return ChatListPanel(
                      onSelect: (index) {
                        Navigate.route(
                          context,
                          ChatMessages(
                            chat: state.chats[index],
                            currentUser: widget.currentUserUid,
                            opponentUid: state.chats[index].participants
                                .firstWhere(
                                  (id) => id != widget.currentUserUid,
                                  orElse: () => '',
                                ),
                            onOpenChat: _openChatFromMention,
                          ),
                        );
                      },
                      chats: state.chats,
                      selectedChatUid: _selectedChatUid,
                      currentUserUid: widget.currentUserUid,
                      onRefresh: () => _refreshChats(context),
                      onOpenNewChat: (chatId, opponentUid) {
                        // For mobile, navigate to the new chat
                        // Try to find the chat in the current state, if not found, create a temporary chat object
                        final participantsList = List<String>.from([widget.currentUserUid, opponentUid])..sort();
                        final newChat = state.chats.firstWhere(
                          (chat) => chat.uid == chatId,
                          orElse: () => ChatModel(
                            uid: chatId,
                            createdBy: widget.currentUserUid,
                            participants: participantsList,
                            participantsKey: participantsList.join('_'),
                            isPinned: false,
                            isFavorite: false,
                            lastMessage: null,
                          ),
                        );
                        Navigate.route(
                          context,
                          ChatMessages(
                            chat: newChat,
                            currentUser: widget.currentUserUid,
                            opponentUid: opponentUid,
                            onOpenChat: _openChatFromMention,
                          ),
                        );
                      },
                    );
                  }
                  return _buildNoChatSelected();
                } else {
                  return Row(
                    children: [
                      ChatListPanel(
                        chats: state.chats,
                        selectedChatUid: _selectedChatUid,
                        onSelect: (index) {
                          final tappedUid = state.chats[index].uid;
                          setState(() {
                            _selectedChatUid = tappedUid;
                            _pendingOpponentUid = null;
                          });
                          // Tapping a chat (even the one already open) must
                          // always clear its unread badge.
                          ChatService.setActiveChat(tappedUid);
                          ChatService.markChatMessagesAsSeen(tappedUid ?? '');
                        },
                        currentUserUid: widget.currentUserUid,
                        onRefresh: () => _refreshChats(context),
                        onOpenNewChat: (chatId, opponentUid) {
                          // For desktop, select the new chat immediately
                          setState(() {
                            _selectedChatUid = chatId;
                            _pendingOpponentUid = opponentUid;
                          });
                        },
                      ),
                      Expanded(
                        child: selectedChat != null
                            ? ChatMessages(
                                key: ValueKey(selectedChat.uid),
                                chat: selectedChat,
                                currentUser: widget.currentUserUid,
                                opponentUid: selectedChat.participants
                                    .firstWhere(
                                      (id) => id != widget.currentUserUid,
                                      orElse: () => '',
                                    ),
                                onOpenChat: _openChatFromMention,
                              )
                            : _buildNoChatSelected(),
                      ),
                    ],
                  );
                }
              },
            );
          } else if (state is ChatError) {
            return ErrorDisplay(error: state.message);
          }
          return const NoData(text: "No chats available");
        },
      ),
      floatingActionButton: kIsMobile || width < 1000
          ? FloatingActionButton(
              heroTag: null,
              foregroundColor: Theme.of(context).colorScheme.surface,
              backgroundColor: Theme.of(context).colorScheme.primary,
              tooltip: "Appeals",
              shape: const CircleBorder(),
              onPressed: () =>
                  Sheet.showSheet(context, widget: const CreateChat()),
              child: const Icon(Iconsax.message_add),
            )
          : null,
    );
  }

  Widget _buildNoChatSelected() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Iconsax.message_search,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Select a Conversation",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Click on a chat from the list to view messages.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatListPanel extends StatefulWidget {
  final List<ChatModel> chats;
  final String? selectedChatUid;
  final ValueChanged<int> onSelect;
  final String currentUserUid;
  final Future<void> Function()? onRefresh;
  final Function(String, String)? onOpenNewChat;

  const ChatListPanel({
    super.key,
    required this.chats,
    this.selectedChatUid,
    required this.onSelect,
    required this.currentUserUid,
    this.onRefresh,
    this.onOpenNewChat,
  });

  @override
  State<ChatListPanel> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends State<ChatListPanel> {
  late final TextEditingController _searchController;
  late final ValueListenable<List<EmployeeModel>> _cacheListenable;
  List<ChatModel> _filteredChats = [];
  List<dynamic> _allUsers = []; // All employees and admins for search
  List<dynamic> _filteredUsers = []; // Filtered users from search
  bool _showUserResults = false; // Whether to show user search results
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _cacheListenable = CacheService().getAllListenableEmployees();

    // Initialize the filtered list with all chats
    _filteredChats = widget.chats;

    // Load all users for search
    _loadAllUsers();

    // Add listeners to trigger filtering
    _searchController.addListener(_filterChats);
    _cacheListenable.addListener(_filterChats);
  }

  Future<void> _loadAllUsers() async {
    try {
      final employees = await EmployeeService.getAllEmployees();
      final admins = await AdminService.getAllAdmins();
      setState(() {
        _allUsers = [...employees, ...admins];
      });
    } catch (e, st) {
      debugPrint('Error loading users for search: $e');
      await ErrorService.recordError(e, st);
    }
  }

  @override
  void dispose() {
    // Clean up listeners and controller
    _searchController.removeListener(_filterChats);
    _cacheListenable.removeListener(_filterChats);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the original chat list from the parent changes, re-apply the filter
    if (widget.chats != oldWidget.chats) {
      _filterChats();
    }
  }

  void _filterChats() {
    final query = _searchController.text.trim().toLowerCase();
    final cacheValue = _cacheListenable.value;

    setState(() {
      // Filter existing chats
      _filteredChats = widget.chats.where((chat) {
        if (chat.isDeletedForUser(widget.currentUserUid)) {
          return false;
        }
        String chatName = '';

        if (chat.isGroupChat) {
          chatName = chat.title ?? '';
        } else {
          final opponentUid = chat.participants.firstWhere(
            (id) => id != widget.currentUserUid,
            orElse: () => '',
          );

          if (opponentUid.isNotEmpty) {
            final employee = cacheValue.cast<EmployeeModel?>().firstWhere(
              (e) => e?.uid == opponentUid,
              orElse: () => null,
            );
            chatName = employee?.name ?? '';
          }
        }

        final lastMessage = chat.lastMessage?.message ?? '';

        if (query.isEmpty) return true;

        final q = query.trim().toLowerCase();
        final name = chatName.toLowerCase();
        final message = lastMessage.toLowerCase();

        return name.contains(q) || message.contains(q);
      }).toList();
      
      // keep pinned chats on top
      _filteredChats.sort((a, b) {
        final ap = a.isPinnedForUser(widget.currentUserUid) ? 1 : 0;
        final bp = b.isPinnedForUser(widget.currentUserUid) ? 1 : 0;
        return bp.compareTo(ap);
      });

      // Search through all users if there's a query
      if (query.isNotEmpty) {
        _filteredUsers = _allUsers.where((user) {
          final userName = (user.name ?? '').toLowerCase();
          final userEmail = (user.email ?? '').toLowerCase();
          final userPhone = (user.mobileNumber ?? '').toLowerCase();
          final employeeId = (user is EmployeeModel ? user.employeeId : '').toLowerCase();
          
          return userName.contains(query) || 
                 userEmail.contains(query) || 
                 userPhone.contains(query) ||
                 employeeId.contains(query);
        }).toList();
        
        // Exclude current user from results
        _filteredUsers = _filteredUsers.where((user) => user.uid != widget.currentUserUid).toList();
        
        // Exclude users that already have a chat
        final existingChatUids = widget.chats
            .where((chat) => !chat.isGroupChat)
            .map((chat) => chat.participants.firstWhere(
              (id) => id != widget.currentUserUid,
              orElse: () => '',
            ))
            .toSet();
        
        _filteredUsers = _filteredUsers.where((user) => !existingChatUids.contains(user.uid)).toList();
        
        _showUserResults = _filteredUsers.isNotEmpty;
      } else {
        _filteredUsers = [];
        _showUserResults = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: kIsMobile || width < 1000 ? double.infinity : 320,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search all users or existing chats',
                      prefixIcon: Icon(
                        Iconsax.search_normal,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),

                if (kIsDesktop || (kIsWeb && width >= 1000)) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      tooltip: "Refresh",
                      icon: Icon(
                        Iconsax.refresh,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      iconSize: 18,
                      onPressed: () async {
                        await widget.onRefresh?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0052D4),
                          Color(0xFF4364F7),
                          Color(0xFF6FB1FC),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4364F7,
                          ).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        tooltip: "Create Chat",
                        icon: const Icon(
                          Iconsax.message_add,
                          color: Colors.white,
                        ),
                        onPressed: () => Sheet.showSheet(
                          context,
                          widget: const CreateChat(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh ?? () async {},
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _getItemCount(),
                    itemBuilder: (context, index) {
                      // Show user search results first if available
                      if (_showUserResults && index < _filteredUsers.length) {
                        final user = _filteredUsers[index];
                        return _UserSearchResultItem(
                          user: user,
                          onTap: () => _startChatWithUser(user),
                        );
                      }
                      
                      // Show divider between user results and chat results
                      if (_showUserResults && _filteredChats.isNotEmpty && index == _filteredUsers.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Existing Chats',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      
                      // Show chat results
                      final chatIndex = _showUserResults && _filteredChats.isNotEmpty 
                          ? index - _filteredUsers.length - 1 
                          : index;
                      
                      if (_filteredChats.isEmpty) {
                        return SizedBox(
                          height: 300,
                          child: NoData(text: "No chats available"),
                        );
                      }
                      final chat = _filteredChats[chatIndex];
                  
                      final originalIndex = widget.chats.indexOf(chat);
                      final isSelected = chat.uid == widget.selectedChatUid;
                  
                      return _ChatListItem(
                        chat: chat,
                        isSelected: isSelected,
                        onTap: () => widget.onSelect(originalIndex),
                        currentUserUid: widget.currentUserUid,
                        onAction: (action) async {
                          switch (action) {
                            case ChatAction.pin:
                              await ChatService.toggleChatPin(
                                chatId: chat.uid!,
                                value: !chat.isPinnedForUser(widget.currentUserUid),
                              );
                              break;
                  
                            case ChatAction.favorite:
                              await ChatService.toggleChatFavorite(
                                chatId: chat.uid!,
                                value: !chat.isFavoriteForUser(
                                  widget.currentUserUid,
                                ),
                              );
                              break;
                            case ChatAction.delete:
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete chat'),
                                  content: const Text(
                                    'This chat will be permanently deleted. Continue?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                  
                              if (confirm == true) {
                                final chatId = chat.uid!;
                                final deletedChat = chat; // ✅ backup
                  
                                // ✅ DELETE
                                await ChatService.deleteChat(chatId: chatId);
                  
                                if (!context.mounted) return;
                  
                                // ✅ SHOW UNDO
                                FlushBar.show(
                                  context,
                                  'Chat deleted',
                                  actionLabel: 'UNDO',
                                  onActionPressed: () async {
                                    await ChatService.restoreChat(deletedChat);
                                    if (!context.mounted) return;
                                    context.read<ChatBloc>().add(StreamChat());
                                  },
                                );
                              }
                              break;
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // if (kIsDesktop) ...[
            //   SizedBox(
            //     width: double.infinity,
            //     child: Padding(
            //       padding: const EdgeInsets.symmetric(
            //         horizontal: 8.0,
            //         vertical: 4,
            //       ),
            //       child: ElevatedButton(
            //         onPressed: () =>
            //             Sheet.showSheet(context, widget: const CreateChat()),
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: Theme.of(context).colorScheme.primary, // button color
            //           foregroundColor: Theme.of(context).colorScheme.surface, // text/icon color
            //           elevation: 3, // shadow
            //           padding: const EdgeInsets.symmetric(vertical: 16),
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(12),
            //           ),
            //         ),
            //         child: const Text("Create Chat"),
            //       ),
            //     ),
            //   ),
            // ],
          ),
        ],
      ),
    );
  }

  int _getItemCount() {
    if (_showUserResults) {
      final hasChats = _filteredChats.isNotEmpty;
      if (hasChats) {
        return _filteredUsers.length + 1 + _filteredChats.length; // users + header + chats
      } else {
        return _filteredUsers.length + 1; // users + no data message
      }
    }
    return _filteredChats.isEmpty ? 1 : _filteredChats.length;
  }

  Future<void> _startChatWithUser(dynamic user) async {
    try {
      // Reset search first
      _searchController.clear();
      
      // Create a new chat with the selected user
      final chatId = await ChatService.createIndividualChat(
        userId: user.uid,
      );
      
      // Navigate to the new chat
      if (chatId.isNotEmpty) {
        // Navigate immediately with the chat info
        widget.onOpenNewChat?.call(chatId, user.uid);
        // Refresh the chat list in the background
        widget.onRefresh?.call();
      }
    } catch (e, st) {
      debugPrint('Error starting chat: $e');
      await ErrorService.recordError(e, st);
      FlushBar.show(
        context,
        'Failed to start chat: $e',
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }
}

class _UserSearchResultItem extends StatelessWidget {
  final dynamic user;
  final VoidCallback onTap;

  const _UserSearchResultItem({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userName = user.name ?? 'Unknown';
    final userEmail = user.email ?? '';
    final userProfileImage = user.profileImageUrl;
    final userRole = user is EmployeeModel ? user.employeeId : 'Admin';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: userProfileImage != null 
            ? CachedNetworkImageProvider(userProfileImage)
            : null,
        child: userProfileImage == null 
            ? Text(userName[0].toUpperCase())
            : null,
      ),
      title: Text(userName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userEmail),
          Text(userRole, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: const Icon(Iconsax.message_add, size: 18),
      onTap: onTap,
    );
  }
}

class _ChatListItem extends StatefulWidget {
  final ChatModel chat;
  final bool isSelected;
  final VoidCallback onTap;
  final String currentUserUid;
  final void Function(ChatAction action) onAction;

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.currentUserUid,
    required this.onAction,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await Spdb.isAdminLoggedIn();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<dynamic> _resolveProfileByUid(String uid) async {
    if (uid.trim().isEmpty) return null;

    final cached = CacheService.getUserByUid(uid);
    if (cached is EmployeeModel || cached is AdminModel) {
      return cached;
    }

    try {
      final employee = await EmployeeService.getEmployee(uid: uid);
      if (employee != null) return employee;
    } catch (_) {}

    try {
      final admin = await AdminService.getAdmin(uid: uid);
      if (admin != null) return admin;
    } catch (_) {}

    return null;
  }

  Future<void> _openChatUserProfile(BuildContext context, String uid) async {
    final width = MediaQuery.of(context).size.width;
    final profile = await _resolveProfileByUid(uid);
    if (!context.mounted) return;

    if (profile is EmployeeModel) {
      if (kIsMobile || width < 1000) {
        await Sheet.showSheet(
          context,
          widget: EmployeeDetails(employee: profile),
        );
      } else {
        await GeneralDialog.showRTLSheet(
          context,
          EmployeeDetails(employee: profile),
        );
      }
      return;
    }

    if (profile is AdminModel) {
      if (kIsMobile || width < 1000) {
        await Sheet.showSheet(context, widget: AdminProfile(admin: profile));
      } else {
        await GeneralDialog.showRTLSheet(context, AdminProfile(admin: profile));
      }
      return;
    }

    FlushBar.show(context, 'User profile not found', isSuccess: false);
  }

  @override
  Widget build(BuildContext context) {
    final ChatModel chat = widget.chat;
    final String currentUserUid = widget.currentUserUid;
    
    final bool isSelfChat = chat.participants.every(
      (id) => id == currentUserUid,
    );

    String opponentUid = isSelfChat
        ? currentUserUid
        : chat.participants.firstWhere(
            (id) => id != currentUserUid,
            orElse: () => currentUserUid,
          );

    var user = CacheService.getUserByUid(opponentUid);

    final String name = isSelfChat ? 'You' : (user?.name ?? '');

    final String imageUrl = user is EmployeeModel
        ? (user.profileImageUrl ?? '')
        : user is AdminModel
        ? (user.profileImageUrl ?? '')
        : '';

    final bool nameValid = name.isNotEmpty;
    final bool avatarValid = imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: widget.isSelected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (widget.isSelected)
                Container(
                  width: 3,
                  height: 36,
                  margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              chat.isGroupChat
                  ? CircleAvatar(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.group, size: 20),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openChatUserProfile(context, opponentUid),
                      child: CircleAvatar(
                        backgroundColor: nameValid
                            ? LetterColors.getColor(name.first)
                            : Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        child: avatarValid
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
                                        baseColor: Theme.of(
                                          context,
                                        ).dividerColor,
                                        highlightColor: Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                        child: Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                        ),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                nameValid ? name.first : '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                    ),
                              ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          chat.isGroupChat
                              ? Text(
                                  '${chat.title ?? ''} ${chat.isFavorite == true ? '❤️' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : InkWell(
                                  onTap: () => _openChatUserProfile(
                                    context,
                                    opponentUid,
                                  ),
                                  child: Text(
                                    '$name ${chat.isFavorite == true ? '❤️' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          Text(
                            // Flatten line breaks so the preview stays on one line
                            (chat.lastMessage?.senderId == currentUserUid
                                    ? ("You: ${chat.lastMessage?.message ?? ''}")
                                    : (chat.lastMessage?.message ?? ''))
                                .replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    if (chat.isPinnedForUser(currentUserUid))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: AppColors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        chat.lastMessage?.timestamp?.formatTime ?? '',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
                      ),
                      const SizedBox(height: 4),
                      _UnreadBadge(
                        key: ValueKey('unread_${chat.uid}'),
                        chatId: chat.uid ?? '',
                      ),
                    ],
                  ),

                  const SizedBox(width: 4),

                  PopupMenuButton<ChatAction>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: widget.onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: ChatAction.pin,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              chat.isPinnedForUser(currentUserUid)
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              chat.isPinnedForUser(currentUserUid)
                                  ? 'Unpin chat'
                                  : 'Pin chat',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: ChatAction.favorite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              chat.isFavoriteForUser(currentUserUid)
                                  ? Iconsax.heart_remove
                                  : Iconsax.heart,
                              size: 20,
                              color: chat.isFavoriteForUser(currentUserUid)
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              chat.isFavoriteForUser(currentUserUid)
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAdmin)
                        PopupMenuItem(
                          value: ChatAction.delete,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete chat',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Unread-count badge for a chat list row.
///
/// Reads from ONE shared listener in [ChatService] (no stream is created in
/// build()), so it never flickers/hides on rebuilds and updates immediately
/// when a chat is opened and its messages are marked as seen.
class _UnreadBadge extends StatelessWidget {
  final String chatId;
  const _UnreadBadge({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: ChatService.unviewedByChat(),
      builder: (context, counts, _) {
        final count = counts[chatId] ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: const BoxConstraints(minWidth: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}