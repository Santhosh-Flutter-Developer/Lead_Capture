import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/constants/constants.dart';

class SearchChatColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
}

class SearchChat extends StatefulWidget {
  final ChatModel chat;

  const SearchChat({super.key, required this.chat});

  @override
  State<SearchChat> createState() => _SearchChatState();
}

class _SearchChatState extends State<SearchChat> {
  final TextEditingController _searchController = TextEditingController();
  List<MessagesModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ChatService.searchMessages(
      chatId: widget.chat.uid ?? '',
      searchTerm: _searchController.text,
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SearchChatColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SearchChatColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            _buildHeader(context),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: _buildSearchBar(),
            ),

            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildEmptyState(
                      Iconsax.search_status,
                      "Search for messages, keywords, or people",
                    )
                  : _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _searchResults.isEmpty
                  ? _buildEmptyState(
                      Iconsax.document_filter,
                      "No messages match your search",
                    )
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = widget.chat.isGroupChat
        ? (widget.chat.title ?? 'Group')
        : 'Chat History';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SearchChatColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: SearchChatColors.primary.withValues(alpha: 0.1),
              child: Icon(
                widget.chat.isGroupChat ? Iconsax.people : Iconsax.message,
                size: 16,
                color: SearchChatColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Deep Search",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: SearchChatColors.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SearchChatColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Iconsax.close_circle,
              color: SearchChatColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: SearchChatColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SearchChatColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        decoration: InputDecoration(
          hintText: "Keywords, dates, or names...",
          hintStyle: const TextStyle(
            color: SearchChatColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: const Icon(
            Iconsax.search_normal_1,
            size: 20,
            color: SearchChatColors.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Iconsax.close_circle, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final message = _searchResults[index];
        final user = CacheService.getUserByUid(message.senderId);

        UserDataModel userData = UserDataModel.fromEmptyMap();
        if (user is AdminModel) {
          userData = UserDataModel(
            uid: user.uid ?? '',
            name: user.name,
            profilePic: user.profileImageUrl,
            userType: UserType.admin,
          );
        } else if (user is EmployeeModel) {
          userData = UserDataModel(
            uid: user.uid ?? '',
            name: user.name,
            profilePic: user.profileImageUrl,
            userType: UserType.employee,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: SearchChatColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SearchChatColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: UserAvatar(userData: userData, size: 40),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    userData.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: SearchChatColors.primary,
                    ),
                  ),
                ),
                Text(
                  message.timestamp.formatDateMonthTime,
                  style: const TextStyle(
                    fontSize: 10,
                    color: SearchChatColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.message,
                style: const TextStyle(
                  color: SearchChatColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            onTap: () {
              // Logic to scroll to message in chat could go here
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SearchChatColors.border.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: SearchChatColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SearchChatColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}