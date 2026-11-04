import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';

class CreateChat extends StatefulWidget {
  final dynamic employee;
  final List<dynamic>? employees;

  const CreateChat({super.key, this.employee, this.employees});

  @override
  State<CreateChat> createState() => _CreateChatState();
}

class _CreateChatState extends State<CreateChat>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _groupName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _chatMessage = TextEditingController();
  final List<dynamic> _members = [];
  final List<dynamic> _selectedMembers = [];
  final List<dynamic> _employees = [];
  final List<dynamic> _admins = [];

  late Future _future;
  int _currentTab = 0;

  // Replaced two specific selections with a single selected user id
  String? _selectedUserId;
  dynamic
  _selectedUser; // optional — holds the selected object if you want to show details

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];
  final ScrollController _scrollController = ScrollController();
  final ScrollController _groupscrollController = ScrollController();

  @override
  void initState() {
    _future = _init();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    super.initState();
  }

  Future<void> _init() async {
    try {
      _members.clear();
      _employees.clear();
      _admins.clear();

      var employees = await EmployeeService.getAllEmployees();
      var admins = await AdminService.getAllAdmins();

      _members.addAll(employees);
      _members.addAll(admins);

      _employees.addAll(employees); // employees only
      _admins.addAll(admins); // admins only

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _chatMessage.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _groupscrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Iconsax.message_add_1,
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
                      "New Conversation",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentTab == 0
                          ? "Start a one-on-one chat with a teammate"
                          : "Create a group and add teammates to it",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AppColors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Individual"),
                Tab(text: "Group"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color? accentColor,
  }) {
    final Color badgeColor = accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: badgeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const WaitingLoading();
                  } else if (snapshot.hasError) {
                    return ErrorDisplay(error: snapshot.error.toString());
                  } else {
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        // -------------------- Individual Chat Tab --------------------
                        Padding(
                          padding: const EdgeInsets.only(right:8.0),
                          child: Scrollbar(
                                              controller: _scrollController,
                                              thumbVisibility: true,
                                              interactive: true,
                                              trackVisibility: true,
                                              radius: const Radius.circular(8),
                                              thickness: 8,
                                              child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionCard(
                                    icon: Iconsax.user,
                                    title: "Select a person",
                                    subtitle:
                                        "Choose who you'd like to start chatting with",
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FormDropdownSearch(
                                          label: 'Select User',
                                          items: _members
                                              .map((e) => e.name)
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              var selected = _members.firstWhere(
                                                (m) => m.name == value,
                                              );
                                              setState(() {
                                                _selectedUserId =
                                                    selected.uid ??
                                                    selected.id ??
                                                    "";
                                                _selectedUser = selected;
                                              });
                                            } else {
                                              setState(() {
                                                _selectedUserId = null;
                                                _selectedUser = null;
                                              });
                                            }
                                          },
                                        ),
                                        if (_selectedUser != null) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _selectedUser is AdminModel
                                                      ? Iconsax.shield_tick
                                                      : Iconsax.user,
                                                  size: 14,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _selectedUser is AdminModel
                                                      ? "Admin"
                                                      : "Employee",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionCard(
                                    icon: Iconsax.message_text,
                                    accentColor: AppColors.secondary,
                                    title: "First message",
                                    subtitle:
                                        "This starts the conversation with them",
                                    child: TextFormField(
                                      controller: _chatMessage,
                                      maxLines: 3,
                                      enableSuggestions: true,
                                      autocorrect: true,
                                      spellCheckConfiguration:
                                          const SpellCheckConfiguration(),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: InputDecoration(
                                        hintText: 'Enter chat message',
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildPrimaryButton(
                                    label: "Create Chat",
                                    icon: Iconsax.message,
                                    onTap: () async {
                                      final selectedUser = _selectedUserId;
                            
                                      if (selectedUser == null ||
                                          selectedUser.isEmpty) {
                                        FlushBar.show(
                                          context,
                                          "Please select a user to chat with.",
                                          isSuccess: false,
                                        );
                                        return;
                                      }
                            
                                      if (_chatMessage.text.isEmpty) {
                                        FlushBar.show(
                                          context,
                                          "Please enter the chat message.",
                                          isSuccess: false,
                                        );
                                        return;
                                      }
                            
                                      try {
                                        futureLoading(context);
                            
                                        debugPrint(
                                          "the chat selected user on the create chat $selectedUser ",
                                        );
                                        final chatId =
                                            await ChatService.createIndividualChat(
                                              userId: selectedUser,
                                            );
                            
                                        await ChatService.sendChatMessage(
                                          chatId: chatId,
                                          message: _chatMessage.text,
                                          attachments: [],
                                          replyFor: null,
                                        );
                            
                                        _chatMessage.clear();
                                        setState(() {});
                            
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                        Navigator.pop(context, true);
                                        FlushBar.show(context, "Chat created");
                                      } catch (e, st) {
                                        await ErrorService.recordError(e, st);
                                        debugPrint(
                                          "${e.toString()}, ${st.toString()}",
                                        );
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                        FlushBar.show(
                                          context,
                                          e.toString(),
                                          isSuccess: false,
                                          error: e,
                                          stackTrace: st,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // -------------------- Group Chat Tab --------------------
                        Padding(
                          padding: const EdgeInsets.only(right:8.0),
                          child: Scrollbar(
                                              controller: _groupscrollController,
                                              thumbVisibility: true,
                                              interactive: true,
                                              trackVisibility: true,
                                              radius: const Radius.circular(8),
                                              thickness: 8,
                                              child: SingleChildScrollView(
                              controller: _groupscrollController,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionCard(
                                    icon: Iconsax.people,
                                    title: "Group Details",
                                    subtitle:
                                        "Give your group a name and a short description",
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Group Name",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        FormFields(
                                          controller: _groupName,
                                          hintText: "Enter group name",
                                          prefixIcon: const Icon(
                                            Iconsax.people,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          "Description",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        FormFields(
                                          controller: _description,
                                          hintText: "Enter group description",
                                          maxLines: 3,
                                          prefixIcon: const Icon(
                                            Iconsax.document_text,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionCard(
                                    icon: Iconsax.profile_2user,
                                    accentColor: AppColors.secondary,
                                    title: "Add Members",
                                    subtitle:
                                        "Pick who should be part of this group",
                                    child: FormMultiDropdowns(
                                      isRequired: true,
                                      items: _members
                                          .map<Object>((e) => e.name)
                                          .toList(),
                                      onListChanged: (selectedList) {
                                        setState(() {
                                          _selectedMembers.clear();
                                          _selectedMembers.addAll(
                                            _members
                                                .where(
                                                  (m) =>
                                                      selectedList.contains(
                                                        m.name,
                                                      ),
                                                )
                                                .toList(),
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildPrimaryButton(
                                    label: "Create Group",
                                    icon: Iconsax.messages_2,
                                    onTap: () async {
                                      if (_groupName.text.isEmpty ||
                                          _selectedMembers.isEmpty) {
                                        FlushBar.show(
                                          context,
                                          "Please fill all required fields.",
                                          isSuccess: false,
                                        );
                                        return;
                                      }
                            
                                      try {
                                        futureLoading(context);
                            
                                        var sessionUser = await Spdb.getUser();
                            
                                        final creatorName = sessionUser.name;
                                        final creatorUid = sessionUser.uid;
                            
                                        List<String> participants =
                                            _selectedMembers
                                                .map<String>(
                                                  (e) => e.uid ?? e.id ?? '',
                                                )
                                                .toList();
                            
                                        if (!participants.contains(creatorUid)) {
                                          participants.add(creatorUid);
                                        }
                            
                                        participants.sort();
                                        final participantsKey = participants.join(
                                          '_',
                                        );
                            
                                        ChatModel chatModel = ChatModel(
                                          createdBy: creatorUid,
                                          participants: participants,
                                          participantsKey: participantsKey,
                                          title: _groupName.text,
                                          description: _description.text,
                                          isGroupChat: true,
                                          isPinned: false,
                                          isFavorite: false,
                                          lastMessage: LastMessageModel(
                                            message: "$creatorName created group",
                                            timestamp: DateTime.now(),
                                            senderId: creatorUid,
                                          ),
                                        );
                            
                                        await ChatService.createGroupChat(
                                          model: chatModel,
                                        );
                            
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                        Navigator.pop(context, true);
                            
                                        FlushBar.show(
                                          context,
                                          "Group chat created",
                                        );
                                      } catch (e, st) {
                                        await ErrorService.recordError(e, st);
                            
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                            
                                        FlushBar.show(
                                          context,
                                          e.toString(),
                                          isSuccess: false,
                                          error: e,
                                          stackTrace: st,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}