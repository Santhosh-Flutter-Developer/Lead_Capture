import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';

class FeedEdit extends StatefulWidget {
  final String uid;
  const FeedEdit({super.key, required this.uid});

  @override
  State<FeedEdit> createState() => _FeedEditState();
}

class _FeedEditState extends State<FeedEdit> {
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // New Media/Files (Selected from device)
  final List<PlatformFile> _newMediaFiles = [];
  final List<PlatformFile> _newDocumentFiles = [];

  // Existing Media/Files (Loaded from FeedModel)
  List<FileModel> _existingMedia = [];
  List<FileModel> _existingAttachments = [];

  // Poll State
  bool _isPollActive = false;
  final TextEditingController _pollQuestionController = TextEditingController();
  List<TextEditingController> _pollOptionControllers = [];

  late Future _future;
  late FeedModel _feedModel;

  @override
  void initState() {
    super.initState();
    _resetPoll();
    _future = _init();
  }

  Future<void> _init() async {
    // 1. Load the Feed Data
    _feedModel = await FeedService.getFeed(uid: widget.uid);

    // 2. Pre-fill Content
    _contentController.text = _feedModel.content;

    // 3. Pre-fill Media & Files
    _existingMedia = List.from(_feedModel.mediaImages);
    _existingAttachments = List.from(_feedModel.attachments);

    // 4. Pre-fill Poll
    if (_feedModel.poll != null) {
      _isPollActive = true;
      _pollQuestionController.text = _feedModel.poll!.question;
      _pollOptionControllers = _feedModel.poll!.options
          .map((option) => TextEditingController(text: option.title))
          .toList();

      // Ensure minimum 2 options if data is somehow corrupted, though unlikely
      while (_pollOptionControllers.length < 2) {
        _pollOptionControllers.add(TextEditingController());
      }
    }

    setState(() {});
  }

  void _resetPoll() {
    _pollQuestionController.clear();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    _pollOptionControllers = [TextEditingController(), TextEditingController()];
  }

  void _togglePoll() {
    setState(() {
      _isPollActive = !_isPollActive;
      if (!_isPollActive) {
        _resetPoll();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 5) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Maximum 5 options allowed",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        final controller = _pollOptionControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  void _pickImage() async {
    final selectedImages = await FilePick.pickFileWithExtensions(
      context,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (selectedImages != null && selectedImages.isNotEmpty) {
      setState(() => _newMediaFiles.addAll(selectedImages));
    }
  }

  void _pickFile() async {
    final selectedFiles = await FilePick.pickFiles(context);
    if (selectedFiles != null && selectedFiles.isNotEmpty) {
      setState(() => _newDocumentFiles.addAll(selectedFiles));
    }
  }

  void _handleSubmit() async {
    try {
      if (_contentController.text.isEmpty &&
          _existingMedia.isEmpty &&
          _newMediaFiles.isEmpty &&
          !_isPollActive) {
        return;
      }

      futureLoading(context);

      // 1. Handle Poll
      PollModel? poll;
      if (_isPollActive && _pollQuestionController.text.isNotEmpty) {
        List<PollOption> options = [];
        for (int i = 0; i < _pollOptionControllers.length; i++) {
          if (_pollOptionControllers[i].text.isNotEmpty) {
            // Check if this option existed before (try to preserve ID) or create new
            String optionId = 'opt_$i';
            if (_feedModel.poll != null &&
                i < _feedModel.poll!.options.length) {
              // Use existing ID if simple edit, or just generate new ones for simplicity in logic
              // usually for edits, we might want to keep IDs to track votes, but for now we regenerate
              // logic to handle existing votes would be complex without more backend info.
              // Assuming edit resets poll or simple update.
              optionId = _feedModel.poll!.options[i].optionId;
            }

            options.add(
              PollOption(
                optionId: optionId,
                title: _pollOptionControllers[i].text,
                votes:
                    _feedModel.poll != null &&
                        i < _feedModel.poll!.options.length
                    ? _feedModel.poll!.options[i].votes
                    : 0,
              ),
            );
          }
        }
        if (options.length >= 2) {
          poll = PollModel(
            pollId:
                _feedModel.poll?.pollId ??
                'poll_${DateTime.now().millisecondsSinceEpoch}',
            question: _pollQuestionController.text,
            options: options,
            votedUserIds: _feedModel.poll?.votedUserIds ?? [],
          );
        }
      }

      // 2. Handle Media (Combine Existing + New Uploads)
      List<FileModel> finalMedia = [..._existingMedia];

      if (_newMediaFiles.isNotEmpty) {
        for (var file in _newMediaFiles) {
          var mimeType = lookupMimeType(file.name) ?? '';
          var bytes = await platformFileToBytes(file);
          String url = await StorageService.uploadBytes(
            bytes: bytes,
            fileName: file.name,
            folder: StorageFolder.feedAttachments,
          );

          finalMedia.add(
            FileModel(
              name: file.name,
              extension: file.extension ?? '',
              size: bytes.length,
              url: url,
              mimeType: mimeType,
            ),
          );
        }
      }

      // 3. Handle Files (Combine Existing + New Uploads)
      List<FileModel> finalAttachments = [..._existingAttachments];

      if (_newDocumentFiles.isNotEmpty) {
        for (var file in _newDocumentFiles) {
          var mimeType = lookupMimeType(file.name) ?? '';
          var bytes = await platformFileToBytes(file);
          String url = await StorageService.uploadBytes(
            bytes: bytes,
            fileName: file.name,
            folder: StorageFolder.feedAttachments,
          );

          finalAttachments.add(
            FileModel(
              name: file.name,
              extension: file.extension ?? '',
              size: bytes.length,
              url: url,
              mimeType: mimeType,
            ),
          );
        }
      }

      // 4. Construct Updated FeedModel
      final updatedFeedModel = FeedModel(
        uid: _feedModel.uid, // Keep original ID
        authorId: _feedModel.authorId, // Keep original Author
        authorName: _feedModel.authorName,
        authorAvatar: _feedModel.authorAvatar,
        content: _contentController.text,
        createdAt: _feedModel.createdAt,
        mediaImages: finalMedia,
        attachments: finalAttachments,
        taggedUsers: _feedModel.taggedUsers,
        reactions: _feedModel.reactions,
        commentsCount: _feedModel.commentsCount,
        comments: _feedModel.comments,
        poll: poll,
      );

      // 5. Update
      await FeedService.editFeed(uid: widget.uid, feed: updatedFeedModel);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      return;
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    _pollQuestionController.dispose();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.5,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Edit Post",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: _SaveButton(onPressed: _handleSubmit),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const WaitingLoading();
          } else if (snapshot.hasError) {
            return ErrorDisplay(error: snapshot.error.toString());
          } else {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                   padding: const EdgeInsets.only(right: 8.0),
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
                            // Header (Author Info)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.08),
                                    AppColors.primary.withValues(alpha: 0.02),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: NetworkImage(
                                        _feedModel.authorAvatar.isNotEmpty
                                            ? _feedModel.authorAvatar
                                            : AppStrings.emptyProfilePhotoUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _feedModel.authorName,
                                        style: Theme.of(context).textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.public,
                                            size: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Editing Feed post",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                      
                            const SizedBox(height: 20),
                      
                            // Content Input
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                              controller: _contentController,
                              maxLines: null,
                              minLines: 3,
                              decoration: InputDecoration(
                                hintText: "What's on your mind?",
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                hintStyle: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            ),
                      
                            const SizedBox(height: 20),
                      
                            // --- MEDIA SECTION (Existing + New) ---
                            if (_existingMedia.isNotEmpty ||
                                _newMediaFiles.isNotEmpty)
                              Container(
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 20),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    // Existing Media (Network)
                                    ..._existingMedia.map(
                                      (media) => _buildMediaPreview(
                                        imageProvider: NetworkImage(media.url),
                                        onRemove: () {
                                          setState(() {
                                            _existingMedia.remove(media);
                                          });
                                        },
                                      ),
                                    ),
                                    // New Media (File)
                                    ..._newMediaFiles.map(
                                      (file) => _buildMediaPreview(
                                        imageProvider: MemoryImage(file.bytes!),
                                        onRemove: () {
                                          setState(() {
                                            _newMediaFiles.remove(file);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      
                            // --- FILES SECTION (Existing + New) ---
                            if (_existingAttachments.isNotEmpty)
                              ..._existingAttachments.map(
                                (fileModel) => _buildFileRow(
                                  name: fileModel.name,
                                  onTap: () => previewAttachment(context, fileModel),
                                  onRemove: () {
                                    setState(() {
                                      _existingAttachments.remove(fileModel);
                                    });
                                  },
                                ),
                              ),
                      
                            if (_newDocumentFiles.isNotEmpty)
                              ..._newDocumentFiles.map(
                                (file) => _buildFileRow(
                                  name: file.name,
                                  onRemove: () {
                                    setState(() {
                                      _newDocumentFiles.remove(file);
                                    });
                                  },
                                ),
                              ),
                      
                            // Poll Section
                            if (_isPollActive) _buildPollCreator(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Toolbar
                _buildBottomToolbar(context),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMediaPreview({
    required ImageProvider imageProvider,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 8,
          right: 18, // Adjusted right padding since margin is on container
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow({
    required String name,
    required VoidCallback onRemove,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPollCreator() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Edit Poll",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: _togglePoll,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pollQuestionController,
            decoration: InputDecoration(
              hintText: "Ask a question...",
              fillColor: Theme.of(context).colorScheme.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_pollOptionControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollOptionControllers[index],
                      decoration: InputDecoration(
                        hintText: "Option ${index + 1}",
                        fillColor: Theme.of(context).colorScheme.surface,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_pollOptionControllers.length > 2)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () => _removePollOption(index),
                    ),
                ],
              ),
            );
          }),
          if (_pollOptionControllers.length < 5)
            TextButton.icon(
              onPressed: _addPollOption,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                "Add Option",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10,
        top: 10,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Add to your post",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _ToolbarIcon(
                icon: Icons.image_outlined,
                label: "Photo",
                color: Colors.green,
                onTap: _pickImage,
              ),
              const SizedBox(width: 18),
              _ToolbarIcon(
                icon: Icons.attach_file,
                label: "File",
                color: Colors.blue,
                onTap: _pickFile,
              ),
              const SizedBox(width: 18),
              _ToolbarIcon(
                icon: Icons.poll_outlined,
                label: "Poll",
                color: Colors.orange,
                onTap: _isPollActive ? null : _togglePoll,
                isActive: _isPollActive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            "Save",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isActive;

  const _ToolbarIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(
                    alpha: isActive || !disabled ? 0.12 : 0.06,
                  ),
                ),
                child: Icon(
                  icon,
                  color: disabled ? color.withValues(alpha: 0.4) : color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: disabled ? color.withValues(alpha: 0.4) : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}