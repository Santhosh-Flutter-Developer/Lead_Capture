import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:line_icons/line_icons.dart';
import 'package:mime/mime.dart';
import 'package:leadcapture/theme/src/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../services/firebase/src/deal_service.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/constants/constants.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;

class DealsViewAppColors {
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

class DealsViewPage extends StatelessWidget {
  final DealModel deal;
  const DealsViewPage({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DealBloc()
        ..add(StreamDealComments(deal.uid!))
        ..add(StreamDealHistory(deal.uid!))
        ..add(StreamDealActivities(deal.uid!)),
      child: DealsView(deal: deal),
    );
  }
}

class DealsView extends StatefulWidget {
  final DealModel deal;
  const DealsView({super.key, required this.deal});

  @override
  State<DealsView> createState() => _DealsViewState();
}

class _DealsViewState extends State<DealsView> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  late DealModel _deal;
  late TabController _tabController;
  String? _currentUid;
  bool _isAdmin = false;
  final ScrollController _vScrollController = ScrollController();
  PermissionModel? _permissions;

  /// Brand gradient shared with the Leads view (avatar, value card, active tab).
  static const LinearGradient _brandGradient = LinearGradient(
    colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
  );
  static const Color _brandGlow = Color(0xFF4364F7);

  @override
  void initState() {
    super.initState();
    _deal = widget.deal;
    _tabController = TabController(length: 5, vsync: this);
    _loadOwnership();
    _refreshDeal();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Deals');
    if (mounted) setState(() {});
  }

  Future<void> _refreshDeal() async {
    final id = _deal.uid;
    if (id == null || id.isEmpty) return;
    try {
      final fresh = await DealService.getDeal(uid: id);
      if (!mounted) return;
      setState(() => _deal = fresh);
    } catch (_) {}
  }

  /// Returns [fallback] for null / blank values so empty fields never render as gaps.
  String _orNA(String? value, {String fallback = 'N/A'}) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? fallback : v;
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

  Future<void> _downloadNotes() async {
    if (_deal.notes.isEmpty) {
      FlushBar.show(context, 'No notes to download', isSuccess: false);
      return;
    }
    try {
      futureLoading(context);
      final bytes = Uint8List.fromList(utf8.encode(_deal.notes));
      final fileName = 'notes_${_deal.dealName.replaceAll(' ', '_')}.txt';
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
    if (_deal.notes.isEmpty) {
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
                            Clipboard.setData(ClipboardData(text: _deal.notes));
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
                      _deal.notes,
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
    final uid = await Spdb.getUid();
    final isAdmin = await Spdb.isAdminLoggedIn();
    setState(() {
      _currentUid = uid;
      _isAdmin = isAdmin;
    });
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
    context.read<DealBloc>().add(
      AddDealComment(dealUid: _deal.uid!, commentText: text),
    );
    _commentController.clear();
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
            title: const Text("Confirm Upload"),
            content: Text(
              "Are you sure you want to upload these $count file${count > 1 ? 's' : ''}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
        _startUpload(files);
      }
    }
  }

  void _startUpload(List<PlatformFile> files) async {
    try {
      futureLoading(context);
      List<FileModel> attachments = [];
      if (files.isNotEmpty) {
        final fileDataList = await Future.wait(
          files.map((pf) async {
            final bytes = await platformFileToBytes(pf);
            return (bytes: bytes, fileName: pf.name);
          }),
        );
        List<String> urls = await StorageService.uploadBytesInBatch(
          files: fileDataList,
          folder: StorageFolder.dealAttachments,
        );
        for (var i = 0; i < files.length; i++) {
          final pf = files[i];
          final mimeType = lookupMimeType(pf.name) ?? '';
          attachments.add(
            FileModel(
              name: pf.name,
              extension: pf.extension ?? '',
              size: pf.size,
              url: urls[i],
              mimeType: mimeType,
            ),
          );
        }
      }
      var user = await Spdb.getUser();
      DealCommentModel dealCommentModel = DealCommentModel(
        userId: user.uid,
        comment:
            "Added ${attachments.length} attachment${attachments.length > 1 ? 's' : ''}",
        attachments: attachments,
        timestamp: DateTime.now(),
        createdBy: user,
      );
      await DealService.addDealComment(
        dealUid: _deal.uid ?? '',
        commentText: dealCommentModel,
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

  void _editComment(DealCommentModel comment) {
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
                            await DealService.editDealComment(
                              dealUid: _deal.uid ?? '',
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
                        ),
                        child: Text(
                          "Submit",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.white),
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

  void _deleteComment(DealCommentModel comment) async {
    if (!_isAdmin) {
      FlushBar.show(
        context,
        'Only admins can delete comments',
        isSuccess: false,
      );
      return;
    }
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
      await DealService.deleteDealComment(
        dealUid: _deal.uid ?? '',
        commentUid: comment.uid ?? '',
      );
    }
  }

  void _scheduleActivity([DealActivityModel? existing]) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<DealBloc>(),
        child: ScheduleDealActivityDialog(
          dealUid: _deal.uid!,
          existing: existing,
        ),
      ),
    );
  }

  IconData _activityIcon(DealActivityType type) {
    switch (type) {
      case DealActivityType.call:
        return Iconsax.call;
      case DealActivityType.meeting:
        return Iconsax.video;
      case DealActivityType.followUp:
        return Iconsax.refresh;
      case DealActivityType.task:
        return Iconsax.task;
    }
  }

  Future<void> _confirmDeleteActivity(DealActivityModel activity) async {
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
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
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
                          backgroundColor: Theme.of(context).colorScheme.error,
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
      context.read<DealBloc>().add(
        DeleteDealActivity(
          dealUid: _deal.uid!,
          activityUid: activity.uid!,
        ),
      );
    }
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
          "Deal Management",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_permissions?.canEdit ?? false) ...[
            if (!_deal.isLocked)
              _appBarButton(Iconsax.edit, "Edit", () async {
                if (kIsMobile || width < 1000) {
                  await Sheet.showSheet(
                    context,
                    widget: DealEdit(uid: _deal.uid ?? ''),
                  );
                } else {
                  await GeneralDialog.showRTLSheet(
                    context,
                    DealEdit(uid: _deal.uid ?? ''),
                  );
                }
                await _refreshDeal();
              }),
            if (_deal.isLocked)
              _appBarButton(Iconsax.lock, "Locked", () {
                FlushBar.show(
                  context,
                  'This deal is locked and cannot be edited',
                  isSuccess: false,
                );
              }),
          ],
          if (!_deal.isLocked && (_permissions?.canDelete ?? false)) ...[
            const SizedBox(width: 8),
            _appBarButton(Iconsax.trash, "Delete", () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => const ConfirmDialog(
                    title: 'Delete Deal',
                    content: 'Are you sure you want to delete this deal?',
                  ),
                );
                if (result != true) return;
                try {
                  final deletedDeal = widget.deal;
                  bool isUndoPressed = false;
                  await DealService.deleteDeal(uid: _deal.uid ?? '');
                  if (!mounted) return;
                  FlushBar.show(
                    context,
                    'Deal deleted successfully',
                    actionLabel: 'UNDO',
                    onActionPressed: () async {
                      isUndoPressed = true;
                      await DealService.restoreDeal(deletedDeal);
                      // refresh your deals list (update event name if needed)
                      context.read<DealBloc>().add(StreamDeals());
                      Navigator.of(context).pop('restored');
                    },
                  );
                  Future.delayed(const Duration(seconds: 4), () {
                    if (!isUndoPressed && mounted) {
                      Navigator.of(context).pop('deleted');
                    }
                  });
                } catch (e, st) {
                  await ErrorService.recordError(e, st);
                  if (mounted) {
                    FlushBar.show(context, e.toString(), isSuccess: false);
                  }
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
                      padding: const EdgeInsets.only(right: 8.0),
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
                  //         left: BorderSide(color: DealsViewAppColors.border),
                  //       ),
                  //       color: DealsViewAppColors.white,
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
    final status = CacheService.dealStatusByUid(_deal.dealStatus ?? '');

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
                      gradient: _brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _brandGlow.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _deal.dealName.isNotEmpty
                            ? _deal.dealName[0].toUpperCase()
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
                              _deal.dealName,
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
                          _orNA(
                            _deal.companyName,
                            fallback: 'Unspecified Company',
                          ),
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

                  // On Desktop, Deal Value stays on the top right
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    _buildDealValueCard(),
                  ],
                ],
              ),

              // On Mobile, Quick Actions and Deal Value stack below
              if (isMobile) ...[
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildActionsRow()),
                    const SizedBox(width: 12),
                    _buildDealValueCard(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDealValueCard() {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: _brandGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Deal Value",
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
                "${_deal.companyCountry?.currencySymbol ?? '₹'}${NumberFormat('#,##,###').format(_deal.dealValue)}",
                style: const TextStyle(
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

  Widget _buildActionsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickAction(
          Iconsax.call,
          "Call",
          () {
            if (_deal.companyMobile?.isNotEmpty ?? false) {
              launchUrl(Uri.parse("tel:${_deal.companyMobile}"));
            }
          },
          tooltip: _deal.companyMobile?.isNotEmpty ?? false
              ? "Call ${_deal.companyMobile}"
              : "No contact number available",
        ),
        _quickAction(
          Iconsax.sms,
          "Email",
          () {},
          tooltip: _deal.dealEmail.isNotEmpty
              ? "Mail ${_deal.dealEmail}"
              : "No contact mail available",
        ),
        _quickAction(
          LineIcons.whatSApp,
          "WA",
          () {
            if (_deal.companyMobile?.isNotEmpty ?? false) {
              launchUrl(Uri.parse("tel:${_deal.companyMobile}"));
            }
          },
          color: Colors.green,
          tooltip: _deal.companyMobile?.isNotEmpty ?? false
              ? "Message ${_deal.companyMobile}"
              : "No contact number available",
        ),
      ],
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
          gradient: _brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _brandGlow.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        tabs: [
          _modernTab(icon: Icons.person_outline_rounded, title: "Deal Profile"),
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
    final website = _deal.companyWebsite?.trim() ?? '';
    return Column(
      children: [
        _infoSection("Engagement Details", [
          _dataPoint(Iconsax.sms, "Email Address", _orNA(_deal.dealEmail)),
          _dataPoint(
            Iconsax.user_add,
            "Assigned Agent",
            _orNA(_deal.createdBy.name),
          ),
          _dataPoint(
            Iconsax.calendar_1,
            "Capture Date",
            DateFormat('MMM dd, yyyy').format(_deal.createdAt),
          ),
        ]),
        const SizedBox(height: 16),
        _infoSection("Corporate Profile", [
          _dataPoint(
            Iconsax.buildings,
            "Company Name",
            _orNA(_deal.companyName),
          ),
          _dataPoint(
            Iconsax.global,
            "Web Presence",
            _orNA(website),
            isLink: website.isNotEmpty,
          ),
          _dataPoint(
            Iconsax.call,
            "Business Contact",
            _orNA(_deal.companyMobile),
          ),
          _dataPoint(
            Iconsax.location,
            "Office Address",
            "${_deal.companyCity?.name ?? 'Unknown'}, ${_deal.companyCountry?.name ?? 'Unknown'}",
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
      child: BlocBuilder<DealBloc, DealState>(
        builder: (context, state) {
          if (state is DealDetailLoaded) {
            if (state.history.isEmpty) {
              return _emptyState(Iconsax.activity, "No activity logs yet");
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.history.length,
              itemBuilder: (context, index) => _buildTimelineItem(
                state.history[index],
                index == state.history.length - 1,
              ),
            );
          }
          return const WaitingLoading();
        },
      ),
    );
  }

  Widget _buildTimelineItem(DealHistoryModel history, bool isLast) {
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
          child: BlocBuilder<DealBloc, DealState>(
            builder: (context, state) {
              if (state is DealDetailLoaded) {
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

  Widget _buildCommentItem(DealCommentModel comment) {
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
                  foregroundColor: Colors.white,
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

  Widget _buildCommentCountIndicator() {
    return BlocBuilder<DealBloc, DealState>(
      builder: (context, state) {
        if (state is DealDetailLoaded) {
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
          BlocBuilder<DealBloc, DealState>(
            builder: (context, state) {
              if (state is DealDetailLoaded) {
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

  Widget _activityItem(DealActivityModel activity) {
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
                        color: Colors.blue.withValues(alpha: .1),
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
                        color: Colors.red.withValues(alpha: .1),
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

  Widget _buildNotesTab() {
    return Column(
      children: [
        _infoSection(
          "Internal Documentation",
          [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _deal.notes.isEmpty
                    ? "No internal notes provided."
                    : _deal.notes,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          trailing: _deal.notes.isEmpty
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
          if (_deal.attachments.isEmpty)
            Text(
              "No documents found.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          else
            ..._deal.attachments.map(
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
                  trailing: IconButton(
                    icon: const Icon(Iconsax.document_download, size: 18),
                    tooltip: 'Download & Open',
                    onPressed: () => _downloadAndOpenAttachment(file),
                  ),
                  onTap: () => previewAttachment(context, file),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}

class ScheduleDealActivityDialog extends StatefulWidget {
  final String dealUid;
  final DealActivityModel? existing;
  const ScheduleDealActivityDialog({
    super.key,
    required this.dealUid,
    this.existing,
  });

  @override
  State<ScheduleDealActivityDialog> createState() =>
      _ScheduleDealActivityDialogState();
}

class _ScheduleDealActivityDialogState
    extends State<ScheduleDealActivityDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();
  DealActivityType selectedType = DealActivityType.call;
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
      final updated = DealActivityModel(
        uid: widget.existing!.uid,
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: selectedType,
        scheduledAt: selectedDateTime!,
        createdBy: widget.existing!.createdBy,
        createdAt: widget.existing!.createdAt,
        completed: widget.existing!.completed,
      );
      context.read<DealBloc>().add(
        EditDealActivity(dealUid: widget.dealUid, activity: updated),
      );
    } else {
      final activity = DealActivityModel(
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: selectedType,
        scheduledAt: selectedDateTime!,
        createdBy: "user",
        createdAt: DateTime.now(),
      );
      context.read<DealBloc>().add(
        AddDealActivity(dealUid: widget.dealUid, activity: activity),
      );
    }
    Navigator.pop(context);
  }

  IconData getTypeIcon(DealActivityType type) {
    switch (type) {
      case DealActivityType.call:
        return Icons.call_rounded;
      case DealActivityType.meeting:
        return Icons.groups_rounded;
      // case DealActivityType.email:
      //   return Icons.email_rounded;
      case DealActivityType.followUp:
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
                      color: theme.primaryColor.withValues(alpha: .1),
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
                          "Manage deal follow-up activities",
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
              DropdownButtonFormField<DealActivityType>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: "Activity Type",
                  // prefixIcon: const Icon(Icons.category_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: DealActivityType.values.map((e) {
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