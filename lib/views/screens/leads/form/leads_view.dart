import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:line_icons/line_icons.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';
import 'package:flutter/foundation.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:path/path.dart' as path;

class LeadsViewAppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color danger = Color(0xFFEF4444);
}

class LeadsViewPage extends StatelessWidget {
  final LeadModel lead;

  const LeadsViewPage({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LeadBloc()
        ..add(StreamLeadComments(lead.uid!))
        ..add(StreamLeadHistory(lead.uid!))
        ..add(StreamLeadActivities(lead.uid!)),
      child: LeadsView(lead: lead),
    );
  }
}

class LeadsView extends StatefulWidget {
  final LeadModel lead;
  const LeadsView({super.key, required this.lead});

  @override
  State<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<LeadsView> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  late LeadModel _lead;
  late LeadCategoryModel widgetLeadCategory;
  late TabController _tabController;
  PermissionModel? _permissions;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _syncLeadCategory();
    _tabController = TabController(length: 5, vsync: this);
    _loadOwnership();
    _refreshLead();
  }

  void _syncLeadCategory() {
    widgetLeadCategory =
        CacheService.leadCategoryByUid(_lead.leadCategory) ??
        LeadCategoryModel.fromEmptyMap();
  }

  Future<void> _refreshLead() async {
    final id = _lead.uid;
    if (id == null || id.isEmpty) return;
    try {
      final fresh = await LeadService.getLead(uid: id);
      if (!mounted) return;
      setState(() {
        _lead = fresh;
        _syncLeadCategory();
      });
    } catch (_) {}
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadAndOpenAttachment(FileModel file) async {
    if (file.url.isEmpty) {
      FlushBar.show(context, 'File URL is unavailable', isSuccess: false);
      return;
    }
    await Download.downloadFromUrl(context, file.url, file.name);
  }

  Future<void> _openAttachmentInBrowser(FileModel file) async {
    if (file.url.isEmpty) {
      FlushBar.show(context, 'File URL is unavailable', isSuccess: false);
      return;
    }
    final uri = Uri.tryParse(file.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        FlushBar.show(context, 'Could not open file', isSuccess: false);
      }
    }
  }

  void _previewAttachment(FileModel file) {
    if (file.url.isEmpty) {
      FlushBar.show(context, 'File URL is unavailable', isSuccess: false);
      return;
    }

    final mime = file.mimeType.toLowerCase();
    final ext = file.extension.toLowerCase();

    final imageExtensions = [
      "png",
      "jpg",
      "jpeg",
      "webp",
      "bmp",
      "gif",
      "tiff",
    ];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    final audioExtensions = ['mp3', 'wav', 'aac'];

    if (mime.startsWith('image/') || imageExtensions.contains(ext)) {
      Navigate.route(context, GalleryScreen(images: [file], initialIndex: 0));
    } else if (mime.startsWith('video/') || videoExtensions.contains(ext)) {
      Navigate.route(context, VideoPlay(file: file));
    } else if (mime.startsWith('audio/') || audioExtensions.contains(ext)) {
      Navigate.route(context, AudioPlay(file: file));
    } else if (ext == 'pdf') {
      Navigate.route(context, _LeadPdfPreviewPage(file: file));
    } else {
      _openAttachmentInBrowser(file);
    }
  }

  Future<void> _downloadNotes() async {
    if (_lead.notes.isEmpty) {
      FlushBar.show(context, 'No notes to download', isSuccess: false);
      return;
    }
    try {
      futureLoading(context);
      final bytes = Uint8List.fromList(utf8.encode(_lead.notes));
      final fileName = 'notes_${_lead.leadName.replaceAll(' ', '_')}.txt';
      final savedPath = await saveFileToDownloads(bytes, fileName: fileName);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(context, 'Notes downloaded successfully', isSuccess: true);
      if (!kIsWeb) openfile(savedPath, context);
    } catch (e, st) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      await ErrorService.recordError(e, st);
      FlushBar.show(context, 'Failed to download notes: $e', isSuccess: false);
    }
  }

  void _previewNotes() {
    if (_lead.notes.isEmpty) {
      FlushBar.show(context, 'No notes to preview', isSuccess: false);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Notes Preview",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy to Clipboard',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _lead.notes));
                            FlushBar.show(context, 'Notes copied to clipboard');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _lead.notes,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadNotes();
                      },
                      icon: const Icon(Iconsax.document_download, size: 18),
                      label: const Text("Download"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadOwnership() async {
    final permissions = await PermissionService.getPermissions('Leads');
    if (!mounted) return;
    setState(() => _permissions = permissions);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    context.read<LeadBloc>().add(
      AddLeadComment(leadUid: _lead.uid!, commentText: text),
    );
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Lead Management",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        actions: [
          if ((_permissions?.canEdit ?? false) && !_lead.leadsConverted) ...[
            _appBarButton(Iconsax.edit, "Edit", () async {
              if (kIsMobile || width < 1000) {
                await Sheet.showSheet(
                  context,
                  widget: LeadEdit(uid: _lead.uid ?? ''),
                );
              } else {
                await GeneralDialog.showRTLSheet(
                  context,
                  LeadEdit(uid: _lead.uid ?? ''),
                );
              }
              await _refreshLead();
            }),
          ],
          if ((_permissions?.canDelete ?? false) && !_lead.leadsConverted) ...[
            const SizedBox(width: 8),
            _appBarButton(Iconsax.trash, "Delete", () async {
              final deleted = await confirmAndDeleteLead(context, _lead);
              if (deleted && context.mounted) {
                // Opener (list / board) refreshes and offers UNDO.
                Navigator.of(context).pop('deleted');
              }
            }, isDanger: true),
          ],
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1000;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 7 : 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right:8.0),
                      child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                          controller: _vScrollController,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfessionalHeader(),
                              const SizedBox(height: 24),
                              _buildModernTabs(),
                              const SizedBox(height: 24),
                              _buildTabContent(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // if (isWide)
                  //   Container(
                  //     width: 450,
                  //     decoration: const BoxDecoration(
                  //       border: Border(
                  //         left: BorderSide(color: LeadsViewAppColors.border),
                  //       ),
                  //       color: LeadsViewAppColors.white,
                  //     ),
                  //     child: _buildCommentsSection(),
                  //   ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _appBarButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 16,
        color: isDanger
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isDanger
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader() {
    final status = CacheService.leadStatusByUid(_lead.leadStatus);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we are on a small screen
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ─── AVATAR ───────────────────────────────
                  Container(
                    width: isMobile ? 60 : 80,
                    height: isMobile ? 60 : 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0052D4),
                          Color(0xFF4364F7),
                          Color(0xFF6FB1FC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4364F7).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _lead.leadName.isNotEmpty
                            ? _lead.leadName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  /// ─── MAIN CONTENT ─────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              _lead.leadName,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            _buildStatusBadge(status?.name ?? 'Unknown'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lead.companyName ?? 'Unspecified Company',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // On Desktop, Quick Actions stay here
                        if (!isMobile) ...[
                          const SizedBox(height: 12),
                          _buildActionsRow(),
                        ],
                      ],
                    ),
                  ),

                  // On Desktop, Lead Value stays on the top right
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    _buildLeadValueCard(),
                  ],
                ],
              ),

              // On Mobile, Quick Actions and Lead Value stack below
              if (isMobile) ...[
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.grey200),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildActionsRow()),
                    const SizedBox(width: 12),
                    _buildLeadValueCard(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Helper to build the Action Buttons
  Widget _buildActionsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickAction(
          Iconsax.call,
          "Call",
          () {
            if (_lead.companyMobile?.isNotEmpty ?? false) {
              launchUrl(Uri.parse("tel:${_lead.companyMobile}"));
            }
          },
          tooltip: _lead.companyMobile?.isNotEmpty ?? false
              ? "Call ${_lead.companyMobile}"
              : "No contact number available",
        ),
        _quickAction(
          Iconsax.sms,
          "Email",
          () {},
          tooltip: _lead.leadEmail.isNotEmpty
              ? "Mail ${_lead.leadEmail}"
              : "No contact mail available",
        ),
        _quickAction(
          LineIcons.whatSApp,
          "WA",
          () {},
          color: Colors.green,
          tooltip: "WhatsApp Message",
        ),
      ],
    );
  }

  /// Helper to build the Lead Value side-box
  Widget _buildLeadValueCard() {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Lead Value",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "${_lead.companyCountry?.currencySymbol ?? '₹'}${NumberFormat('#,##,###').format(_lead.leadValue)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _quickAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
    String? tooltip,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: (color ?? Theme.of(context).colorScheme.primary).withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),

        indicatorSize: TabBarIndicatorSize.tab,

        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4364F7).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        tabs: [
          _modernTab(icon: Icons.person_outline_rounded, title: "Lead Profile"),

          _modernTab(icon: Icons.folder_open_rounded, title: "Files & Notes"),

          _modernTab(icon: Icons.history_rounded, title: "History Log"),

          _modernTab(
            icon: Icons.chat_bubble_outline_rounded,
            title: "Comments",
          ),

          _modernTab(icon: Icons.event_note_rounded, title: "Activities"),
        ],
      ),
    );
  }

  Widget _modernTab({required IconData icon, required String title}) {
    return Tab(
      height: 46,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),

          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return IndexedStack(
          index: _tabController.index,
          children: [
            _buildOverviewTab(),
            _buildNotesTab(),
            _buildTimelineTab(),
            _buildCommentsTab(),
            _buildActivitiesTab(),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      children: [
        _infoSection("Engagement Details", [
          _dataPoint(Iconsax.sms, "Email Address", _lead.leadEmail),
          _dataPoint(Iconsax.category, "Lead Segment", widgetLeadCategory.name),
          _dataPoint(Iconsax.user_add, "Assigned Agent", _lead.createdBy.name),
          _dataPoint(
            Iconsax.calendar_1,
            "Capture Date",
            DateFormat('MMM dd, yyyy').format(_lead.createdAt),
          ),
        ]),
        const SizedBox(height: 16),
        _infoSection("Corporate Profile", [
          _dataPoint(
            Iconsax.buildings,
            "Company Name",
            _lead.companyName ?? 'N/A',
          ),
          _dataPoint(
            Iconsax.global,
            "Web Presence",
            _lead.companyWebsite ?? 'N/A',
            isLink: true,
          ),
          _dataPoint(
            Iconsax.call,
            "Business Contact",
            _lead.companyMobile ?? 'N/A',
          ),
          _dataPoint(
            Iconsax.location,
            "Office Address",
            "${_lead.companyCity?.name ?? 'Unknown'}, ${_lead.companyCountry?.name ?? 'Unknown'}",
          ),
        ]),
      ],
    );
  }

  Widget _infoSection(String title, List<Widget> children, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 40, runSpacing: 24, children: children),
        ],
      ),
    );
  }

  Widget _dataPoint(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
  }) {
    return SizedBox(
      width: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isLink
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Icon(
                Iconsax.message_text_1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                "Comments ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _buildCommentCountIndicator(),
            ],
          ),
        ),
        const Divider(height: 1),

        SizedBox(
          height: 400,
          child: BlocBuilder<LeadBloc, LeadState>(
            builder: (context, state) {
              if (state is LeadDetailLoaded) {
                if (state.comments.isEmpty) {
                  return _emptyState(
                    Iconsax.message_minus,
                    "No comments found",
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: state.comments.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 32),
                  itemBuilder: (context, index) =>
                      _buildCommentItem(state.comments[index]),
                );
              }
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),

        _buildCommentInputArea(),
      ],
    );
  }

  Widget _buildCommentItem(LeadCommentModel comment) {
    final name = comment.createdBy.name;
    final date = comment.timestamp;

    var userId = comment.createdBy.uid;
    var user = CacheService.getUserByUid(userId);

    UserDataModel userDataModel = UserDataModel.fromEmptyMap();
    if (user is AdminModel) {
      userDataModel = UserDataModel(
        uid: userId,
        name: user.name,
        desc: user.email,
        profilePic: user.profileImageUrl,
        userType: UserType.admin,
      );
    } else if (user is EmployeeModel) {
      userDataModel = UserDataModel(
        uid: userId,
        name: user.name,
        desc: user.email,
        profilePic: user.profileImageUrl,
        userType: UserType.employee,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(userData: userDataModel),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),

                        Text(
                          comment.comment,
                          style: TextStyle(
                            height: 1.5,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(date),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          showMenu(
                            context: context,
                            color: Theme.of(
                              context,
                            ).colorScheme.surface, // popup background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            position: const RelativeRect.fromLTRB(
                              100,
                              100,
                              0,
                              0,
                            ),
                            items: [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: const [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ).then((value) {
                            if (value == 'edit') {
                              _editComment(comment);
                            } else if (value == 'delete') {
                              _deleteComment(comment);
                            }
                          });
                        },
                        child: Icon(
                          Iconsax.more,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (comment.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                AttachmentPreview(attachments: comment.attachments),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _commentController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Add a comment...",
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: IconButton(
                tooltip: 'Add Attachment',
                icon: Icon(Iconsax.document),
                onPressed: () {
                  _uploadFiles();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _addComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Post Comment",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: BlocBuilder<LeadBloc, LeadState>(
        builder: (context, state) {
          if (state is LeadDetailLoaded) {
            if (state.history.isEmpty) {
              return _emptyState(Iconsax.activity, "No activity logs yet");
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ListView.builder(
                itemCount: state.history.length,
                itemBuilder: (context, index) => _buildTimelineItem(
                  state.history[index],
                  index == state.history.length - 1,
                ),
              ),
            );
          }

          return const WaitingLoading();
        },
      ),
    );
  }

  Widget _buildTimelineItem(LeadHistoryModel history, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.updateDisposition,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${CacheService.getUserByUid(history.userId)?.name ?? 'System'}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'MMM dd, yyyy • hh:mm a',
                    ).format(history.timestamp),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: _buildCommentsSection(),
    );
  }

  Widget _buildActivitiesTab() {
    return Container(
      // Match the padding and decoration of your _infoSection
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ─── HEADER SECTION ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Activities",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: _scheduleActivity,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Iconsax.add, size: 18),
                label: const Text(
                  "Schedule",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          /// ─── CONTENT SECTION ──────────────────────────
          BlocBuilder<LeadBloc, LeadState>(
            builder: (context, state) {
              if (state is LeadDetailLoaded) {
                if (state.activities.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: _emptyState(
                      Iconsax.calendar,
                      "No activities scheduled yet",
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.activities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) => _activityItem(state.activities[i]),
                );
              }
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: WaitingLoading(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _activityItem(LeadActivityModel activity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _activityIcon(activity.type),
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Iconsax.clock,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        'MMM dd • hh:mm a',
                      ).format(activity.scheduledAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: "More",
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            color: Theme.of(context).colorScheme.surface,
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'edit') {
                _scheduleActivity(activity);
              } else if (value == 'delete') {
                _confirmDeleteActivity(activity);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Edit Activity',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuItem<String>(
                value: 'delete',
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Delete Activity',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteActivity(LeadActivityModel activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ICON
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),

                const SizedBox(height: 20),

                /// TITLE
                const Text(
                  "Delete Activity?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 12),

                /// DESCRIPTION
                Text(
                  "Are you sure you want to delete '${activity.title}'?\n\nThis action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                /// BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      context.read<LeadBloc>().add(
        DeleteLeadActivity(leadUid: _lead.uid!, activityUid: activity.uid!),
      );
    }
  }

  Widget _buildCommentCountIndicator() {
    return BlocBuilder<LeadBloc, LeadState>(
      builder: (context, state) {
        if (state is LeadDetailLoaded) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              state.comments.length.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        _infoSection(
          "Internal Documentation",
          [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _lead.notes.isEmpty
                    ? "No internal notes provided."
                    : _lead.notes,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          trailing: _lead.notes.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Iconsax.eye, size: 18),
                      tooltip: 'Preview Note',
                      onPressed: () => _previewNotes(),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.document_download, size: 18),
                      tooltip: 'Download Note',
                      onPressed: () => _downloadNotes(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _infoSection("Shared Attachments", [
          if (_lead.attachments.isEmpty)
            Text(
              "No documents found.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          else
            ..._lead.attachments.map(
              (file) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Iconsax.document_text,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    file.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    file.url.isEmpty
                        ? 'Unavailable'
                        : '${file.extension.toUpperCase()} · ${_formatFileSize(file.size)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // IconButton(
                      //   icon: const Icon(Iconsax.eye, size: 18),
                      //   tooltip: 'Preview',
                      //   onPressed: () => _previewAttachment(file),
                      // ),
                      IconButton(
                        icon: const Icon(Iconsax.document_download, size: 18),
                        tooltip: 'Download & Open',
                        onPressed: () => _downloadAndOpenAttachment(file),
                      ),
                      // IconButton(
                      //   icon: const Icon(Iconsax.export_1, size: 16),
                      //   tooltip: 'Open in Browser',
                      //   onPressed: () => _openAttachmentInBrowser(file),
                      // ),
                    ],
                  ),
                  onTap: () => _downloadAndOpenAttachment(file),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  void _editComment(LeadCommentModel comment) {
    final TextEditingController controller = TextEditingController(
      text: comment.comment,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Edit",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.50,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  /// Textbox
                  FormFields(
                    controller: controller,
                    label: "Comment",
                    hintText: "Edit your comment here...",
                  ),

                  const SizedBox(height: 20),

                  /// Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final value = controller.text.trim();

                          if (value.isNotEmpty) {
                            await LeadService.editLeadComment(
                              leadUid: _lead.uid ?? '',
                              commentUid: comment.uid ?? '',
                              commentText: value,
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                        child: const Text(
                          "Submit",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },

      /// Animation
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  IconData _activityIcon(LeadActivityType type) {
    switch (type) {
      case LeadActivityType.call:
        return Iconsax.call;
      case LeadActivityType.meeting:
        return Iconsax.video;
      case LeadActivityType.followUp:
        return Iconsax.refresh;
      case LeadActivityType.task:
        return Iconsax.task;
    }
  }

  void _deleteComment(LeadCommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              "Delete",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LeadService.deleteLeadComment(
        leadUid: _lead.uid ?? '',
        commentUid: comment.uid ?? '',
      );
    }
  }

  void _uploadFiles() async {
    var files = await FilePick.pickFiles(context);

    if (files?.isNotEmpty ?? false) {
      final int count = files!.length;

      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text("Confirm Upload"),
            content: Text(
              "Are you sure you want to upload these $count file${count > 1 ? 's' : ''}?",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  "Upload",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                ),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        _startUpload(files.cast<File>());
      }
    }
  }

  void _startUpload(List<File> files) async {
    try {
      futureLoading(context);
      List<FileModel> attachments = [];

      if (files.isNotEmpty) {
        List<String> urls = await StorageService.uploadFilesInBatch(
          files: files,
          folder: StorageFolder.leadAttachments,
        );

        for (var i = 0; i < files.length; i++) {
          var file = files[i];
          var mimeType = lookupMimeType(file.path) ?? '';

          attachments.add(
            FileModel(
              name: path.basename(file.path),
              extension: path.extension(file.path).replaceAll('.', ''),
              size: file.lengthSync(),
              url: urls[i],
              mimeType: mimeType,
            ),
          );
        }
      }

      var user = await Spdb.getUser();

      LeadCommentModel leadCommentModel = LeadCommentModel(
        userId: user.uid,
        comment:
            "Added ${attachments.length} attachment${attachments.length > 1 ? 's' : ''}",
        attachments: attachments,
        timestamp: DateTime.now(),
        createdBy: user,
      );

      await LeadService.addLeadComment(
        leadUid: _lead.uid ?? '',
        comment: leadCommentModel,
      );
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      FlushBar.show(
        context,
        "Failed to upload files: ${e.toString()}",
        isSuccess: false,
      );
    }
  }

  void _scheduleActivity([LeadActivityModel? existing]) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<LeadBloc>(),
        child: ScheduleLeadActivityDialog(
          leadUid: _lead.uid!,
          existing: existing,
        ),
      ),
    );
  }
}

class ScheduleLeadActivityDialog extends StatefulWidget {
  final String leadUid;
  final LeadActivityModel? existing;

  const ScheduleLeadActivityDialog({
    super.key,
    required this.leadUid,
    this.existing,
  });

  @override
  State<ScheduleLeadActivityDialog> createState() =>
      _ScheduleLeadActivityDialogState();
}

class _ScheduleLeadActivityDialogState
    extends State<ScheduleLeadActivityDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  /// ✅ SINGLE DATETIME CONTROLLER
  final TextEditingController dateTimeController = TextEditingController();

  LeadActivityType selectedType = LeadActivityType.call;

  DateTime? selectedDateTime;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final e = widget.existing;

    if (e != null) {
      titleController.text = e.title;
      descController.text = e.description;

      selectedType = e.type;
      selectedDateTime = e.scheduledAt;

      /// ✅ SET DATETIME TEXT
      dateTimeController.text =
          "${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} "
          "${selectedDateTime!.hour.toString().padLeft(2, '0')}:"
          "${selectedDateTime!.minute.toString().padLeft(2, '0')}:00";
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    dateTimeController.dispose();
    super.dispose();
  }

  /// ✅ PICK DATE & TIME
  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: selectedDateTime ?? DateTime.now(),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: selectedDateTime != null
          ? TimeOfDay.fromDateTime(selectedDateTime!)
          : TimeOfDay.now(),
    );

    if (time == null) return;

    final finalDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      selectedDateTime = finalDateTime;

      /// ✅ UPDATE CONTROLLER
      dateTimeController.text =
          "${finalDateTime.day}/${finalDateTime.month}/${finalDateTime.year} "
          "${time.hour.toString().padLeft(2, '0')}:"
          "${time.minute.toString().padLeft(2, '0')}:00";
    });
  }

  void saveActivity() {
    if (titleController.text.trim().isEmpty || selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (_isEditing) {
      final updated = LeadActivityModel(
        uid: widget.existing!.uid,
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: selectedType,
        scheduledAt: selectedDateTime!,
        createdBy: widget.existing!.createdBy,
        createdAt: widget.existing!.createdAt,
        completed: widget.existing!.completed,
      );

      context.read<LeadBloc>().add(
        EditLeadActivity(leadUid: widget.leadUid, activity: updated),
      );
    } else {
      final activity = LeadActivityModel(
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: selectedType,
        scheduledAt: selectedDateTime!,
        createdBy: "user",
        createdAt: DateTime.now(),
      );

      context.read<LeadBloc>().add(
        AddLeadActivity(leadUid: widget.leadUid, activity: activity),
      );
    }

    Navigator.pop(context);
  }

  IconData getTypeIcon(LeadActivityType type) {
    switch (type) {
      case LeadActivityType.call:
        return Icons.call_rounded;
      case LeadActivityType.meeting:
        return Icons.groups_rounded;
      // case LeadActivityType.email:
      //   return Icons.email_rounded;
      case LeadActivityType.followUp:
        return Icons.update_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_calendar_rounded
                          : Icons.add_task_rounded,
                      color: theme.primaryColor,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? "Edit Activity" : "Schedule Activity",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "Manage lead follow-up activities",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// TITLE
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Activity Title *",
                  hintText: "Enter activity title",
                  // prefixIcon: const Icon(Icons.title_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              /// DESCRIPTION
              TextFormField(
                controller: descController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Description",
                  hintText: "Add notes or details",
                  alignLabelWithHint: true,
                  // prefixIcon: const Padding(
                  //   padding: EdgeInsets.only(bottom: 60),
                  //   child: Icon(Icons.description_rounded),
                  // ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              /// TYPE
              DropdownButtonFormField<LeadActivityType>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: "Activity Type",
                  // prefixIcon: const Icon(Icons.category_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: LeadActivityType.values.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Icon(getTypeIcon(e), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          e.name
                              .replaceAllMapped(
                                RegExp(r'([A-Z])'),
                                (match) => ' ${match.group(0)}',
                              )
                              .toUpperCase(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => selectedType = v);
                  }
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: dateTimeController,
                readOnly: true,
                onTap: pickDateTime,
                decoration: InputDecoration(
                  labelText: "Date & Time *",
                  hintText: "DD/MM/YYYY HH:MM:SS",
                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),

                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: saveActivity,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_isEditing ? "Update" : "Save Activity"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadPdfPreviewPage extends StatelessWidget {
  final FileModel file;
  const _LeadPdfPreviewPage({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          file.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.document_download),
            onPressed: () =>
                Download.downloadFromUrl(context, file.url, file.name),
          ),
        ],
      ),
      body: SfPdfViewer.network(
        file.url,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}