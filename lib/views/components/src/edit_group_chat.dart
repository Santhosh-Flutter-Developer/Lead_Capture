import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class EditGroupChat extends StatefulWidget {
  final ChatModel chat;
  final List<dynamic>? employees;
  final List<dynamic>? admins;

  const EditGroupChat({
    super.key,
    required this.chat,
    this.employees,
    this.admins,
  });

  @override
  State<EditGroupChat> createState() => _EditGroupChatState();
}

class _EditGroupChatState extends State<EditGroupChat> {
  final TextEditingController _groupName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final List<dynamic> _members = [];
  List<dynamic> _selectedMembers = [];

  late Future _future;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];
  final ScrollController _groupscrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<void> _init() async {
    try {
      _members.clear();
      _selectedMembers.clear();

      final employees = await EmployeeService.getAllEmployees();
      final admins = await AdminService.getAllAdmins();

      _members.addAll(employees);
      _members.addAll(admins);

      // Prefill group name & description
      _groupName.text = widget.chat.title ?? '';
      _description.text = widget.chat.description ?? '';

      // Create participant ID set
      final Set<String> participantIds = widget.chat.participants
          .map((e) => e.toString())
          .toSet();

      // Prefill selected members
      _selectedMembers = _members.where((member) {
        final memberId = (member.uid ?? member.id)?.toString();
        return memberId != null && participantIds.contains(memberId);
      }).toList();

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  @override
  void dispose() {
    _groupName.dispose();
    _description.dispose();
    _groupscrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
            child: const Icon(Iconsax.people, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit Group",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update the group's name, description and members",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
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
                    return Padding(
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
                                    "The name and description shown to all members",
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Group Name",
                                      style: Theme.of(context).textTheme.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
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
                                      style: Theme.of(context).textTheme.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
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
                                title: "Members",
                                subtitle: "Who is part of this group",
                                child: FormMultiDropdowns(
                                  items: _members
                                      .map<String>((e) => e.name.trim())
                                      .toList(),
                                  selectedItems: _selectedMembers
                                      .map<String>((e) => e.name.trim())
                                      .toList(),
                                  onListChanged: (list) {
                                    setState(() {
                                      _selectedMembers = _members
                                          .where((m) => list.contains(m.name.trim()))
                                          .toList();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildPrimaryButton(
                                label: "Update Group",
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
                        
                                    await ChatService.updateGroupChat(
                                      chatId: widget.chat.uid!,
                                      title: _groupName.text.trim(),
                                      description: _description.text.trim(),
                                      participantIds: _selectedMembers
                                          .map<String>((e) => e.uid ?? e.id ?? '')
                                          .toList(),
                                    );
                        
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                    Navigator.pop(context, true);
                                    FlushBar.show(context, "Group chat updated");
                                  } catch (e, st) {
                                    await ErrorService.recordError(e, st);
                                    debugPrint("${e.toString()}, ${st.toString()}");
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