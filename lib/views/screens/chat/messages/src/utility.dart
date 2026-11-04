part of 'chat_messages.dart';

// --- UTILITY WIDGETS (Unchanged, but kept in file) ---

/// Renders markdown-formatted text.
class MarkdownText extends StatelessWidget {
  final String message;

  const MarkdownText({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: message,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).textTheme.bodyMedium,
        a: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.blue,
          // decoration: TextDecoration.underline,
        ),
        code: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'Manrope'),
        strong: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        em: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        blockquote: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppColors.grey,
        ),
      ),
    );
  }
}

/// Renders a preview for a URL.
class UrlPreview extends StatelessWidget {
  final String url;
  final bool isSender;
  const UrlPreview({super.key, required this.url, required this.isSender});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: EdgeInsets.only(
        left: isSender ? 40 : 0,
        right: isSender ? 0 : 40,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: AnyLinkPreview(
          link: url,
          displayDirection: UIDirection.uiDirectionHorizontal,
          showMultimedia: true,
          bodyMaxLines: 5,
          bodyTextOverflow: TextOverflow.ellipsis,
          titleStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
          bodyStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.grey),
          cache: const Duration(days: 7),
          backgroundColor: AppColors.white,
          borderRadius: 12,
          removeElevation: false,
          boxShadow: const [BoxShadow(blurRadius: 3, color: AppColors.grey)],
          onTap: () => launchUrl(Uri.parse(url)),
        ),
      ),
    );
  }
}

/// Renders a preview for file attachments (images, videos, audio, etc.).
class AttachmentPreview extends StatelessWidget {
  final List<FileModel> attachments;

  /// Only used to tint inline voice messages (sent vs received).
  final bool isSender;
  const AttachmentPreview({
    super.key,
    required this.attachments,
    this.isSender = false,
  });

  static bool _isImage(FileModel e) =>
      e.mimeType.toLowerCase().startsWith('image/') ||
      _kImageExt.contains(e.extension.toLowerCase());

  static bool _isVideo(FileModel e) =>
      e.mimeType.toLowerCase().startsWith('video/') ||
      _kVideoExt.contains(e.extension.toLowerCase());

  static bool _isAudio(FileModel e) =>
      e.mimeType.toLowerCase().startsWith('audio/') ||
      _kAudioExt.contains(e.extension.toLowerCase());

  /// Images / videos are laid out WhatsApp-style in a grid (1, 2, 3, or 2x2
  /// with a "+N" overlay) so nothing needs horizontal scrolling. Voice, audio
  /// and documents are stacked below, one per row.
  @override
  Widget build(BuildContext context) {
    final width = _chatMediaWidth(context);
    final media = attachments.where((e) => _isImage(e) || _isVideo(e)).toList();
    final others = attachments
        .where((e) => !(_isImage(e) || _isVideo(e)))
        .toList();
    final images = media.where(_isImage).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MediaGridLayout(
              count: media.length,
              width: width,
              tileBuilder: (context, i) =>
                  _buildMediaTile(media[i], images, context),
            ),
          ),
        for (final e in others)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _isAudio(e)
                ? (e.isVoice
                      ? VoiceMessagePlayer(
                          key: ValueKey(e.url),
                          file: e,
                          isSender: isSender,
                        )
                      : _buildAudio(e, context, width))
                : _buildDocument(e, context, width),
          ),
      ],
    );
  }

  Widget _buildMediaTile(
    FileModel e,
    List<FileModel> images,
    BuildContext context,
  ) {
    if (_isVideo(e)) {
      return GestureDetector(
        onTap: () => Navigate.route(context, VideoPlay(file: e)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3A), Color(0xFF111111)],
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final index = images.indexOf(e);
        Navigate.route(
          context,
          GalleryScreen(images: images, initialIndex: index < 0 ? 0 : index),
        );
      },
      child: CachedNetworkImage(
        imageUrl: e.url,
        fit: BoxFit.cover,
        memCacheWidth: 600,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (context, url, error) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _buildAudio(FileModel e, BuildContext context, double width) {
    return GestureDetector(
      onTap: () => Navigate.route(context, AudioPlay(file: e)),
      child: Container(
        width: width,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "00:30",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocument(FileModel e, BuildContext context, double width) {
    return GestureDetector(
      onTap: () => previewAttachment(context, e),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: e.extension.getColorForFile,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.extension.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    path.basename(e.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(e.size),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Iconsax.arrow_right_3,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

/// A tile that displays the content of a message being replied to.
class ReplyTile extends StatefulWidget {
  final MessagesModel? message;
  const ReplyTile({super.key, this.message});

  @override
  State<ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: CachedNetworkImage(
                          imageUrl:
                              CacheService.adminByUid(
                                        widget.message?.senderId ?? '',
                                      )?.profileImageUrl !=
                                      null &&
                                  (CacheService.adminByUid(
                                    widget.message?.senderId ?? '',
                                  )?.profileImageUrl)!.isNotEmpty
                              ? (CacheService.adminByUid(
                                  widget.message?.senderId ?? '',
                                )?.profileImageUrl)!
                              : AppStrings.emptyProfilePhotoUrl,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: AppColors.grey300,
                            highlightColor: AppColors.grey100,
                            child: Container(color: AppColors.white),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          height: 20,
                          width: 20,
                          fit: BoxFit.cover,
                        ),
                      ),

                      const SizedBox(width: 5),
                      // Name
                      Text(
                        CacheService.adminByUid(
                              widget.message?.senderId ?? '',
                            )?.name ??
                            '',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  // Message with ellipsis
                  SizedBox(
                    width: double.infinity, // Force width constraint
                    child: Text(
                      widget.message?.message ?? '',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: AppColors.grey700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-screen audio player.
class AudioPlay extends StatefulWidget {
  final FileModel file;

  const AudioPlay({super.key, required this.file});

  @override
  State<AudioPlay> createState() => _AudioPlayState();
}

class _AudioPlayState extends State<AudioPlay> {
  late AudioPlayer _player;
  final List<StreamSubscription> _subs = [];
  bool isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (widget.file.mimeType.contains('audio')) {
      _initializePlayer();
    }
    // Every callback checks `mounted`: events arriving after the page is
    // closed (or while a download is running) used to call setState() on a
    // disposed State and crash.
    _subs.addAll([
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          isPlaying = false;
          _position = Duration.zero;
        });
      }),
      _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => isPlaying = state == PlayerState.playing);
      }),
    ]);
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.setSourceUrl(widget.file.url);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (!mounted) return;
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
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    try {
      if (isPlaying) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Could not play audio', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          if (widget.file.mimeType.contains('audio'))
            Center(
              child: Row(
                children: [
                  IconButton(
                    iconSize: 24, // smaller size
                    padding: EdgeInsets.zero, // no extra padding
                    constraints:
                        const BoxConstraints(), // remove default button constraints
                    color: AppColors.white,
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlayPause,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: _duration.inSeconds > 0
                                  ? _position.inSeconds
                                        .clamp(0, _duration.inSeconds)
                                        .toDouble()
                                  : 0.0,
                              max: _duration.inSeconds > 0
                                  ? _duration.inSeconds.toDouble()
                                  : 1.0,
                              onChanged: (value) async {
                                await _player.seek(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                              activeColor: AppColors.white,
                              inactiveColor: AppColors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.white),
                        ),
                        Text(
                          " / ${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0, // <-- add this to make the Row take full width
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Iconsax.close_circle,
                          color: AppColors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.file.name,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: AppColors.white),
                          ),
                          Text(
                            "${(widget.file.size / 1000000).toStringAsFixed(2)} MB",
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.white,
                    ),
                    onPressed: () => Download.downloadWithLoading(
                      context,
                      widget.file.url,
                      widget.file.name,
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
}

/// A full-screen video player.
class VideoPlay extends StatefulWidget {
  final FileModel file;
  const VideoPlay({super.key, required this.file});

  @override
  State<VideoPlay> createState() => _VideoPlayState();
}

class _VideoPlayState extends State<VideoPlay> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  // ignore: unused_field
  bool _isPlaying = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _useSystemPlayer = false;

  @override
  void initState() {
    super.initState();
    // On Windows, use system player by default due to video_player limitations.
    // NOTE: uses the web-safe `kIsWindows` helper (lib/utils/src/platform.dart),
    // not dart:io's `Platform.isWindows`, which throws
    // `Unsupported operation: Platform._operatingSystem` on Flutter Web.
    if (kIsWindows) {
      setState(() {
        _useSystemPlayer = true;
      });
    } else {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.file.url),
      );
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: false,
          looping: false,
          showControls: true,
          aspectRatio: _controller.value.aspectRatio,
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _openInSystemPlayer() async {
    final uri = Uri.parse(widget.file.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {
      _isPlaying = _controller.value.isPlaying;
    });
  }

  String _formatTime(Duration duration) {
    return "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          if (_useSystemPlayer)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opening in System Player',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video will open in your default video player',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openInSystemPlayer,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load video',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openInSystemPlayer,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in System Player'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            )
          else if (_chewieController != null)
            Center(child: Chewie(controller: _chewieController!)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Iconsax.close_circle,
                          color: AppColors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.file.name,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: AppColors.white),
                          ),
                          Text(
                            "${(widget.file.size / 1000000).toStringAsFixed(2)} MB",
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.white,
                    ),
                    onPressed: () => Download.downloadWithLoading(
                      context,
                      widget.file.url,
                      widget.file.name,
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
}