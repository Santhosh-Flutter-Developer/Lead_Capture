import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/utils/src/download.dart';
import 'package:leadcapture/utils/src/route.dart' as navigate;
import 'package:path/path.dart' as path;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/services/services.dart';

class ChatAttachment extends StatefulWidget {
  final String chatId;
  const ChatAttachment({super.key, required this.chatId});

  @override
  State<ChatAttachment> createState() => _ChatAttachmentState();
}

class _ChatAttachmentState extends State<ChatAttachment> {
  List<FileModel> media = [];
  List<String> links = [];
  List<FileModel> docs = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    final result = await ChatService.getChatMessages(uid: widget.chatId);

    final mediaList = <FileModel>[];
    final linkList = <String>{}; // prevent duplicates
    final docList = <FileModel>[];

    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    for (final msg in result) {
      // 🔥 1. MEDIA + DOCS FROM ATTACHMENTS
      for (final file in msg.attachments) {
        final mime = file.mimeType.toLowerCase();

        if (mime.startsWith('image/') || mime.startsWith('video/')) {
          mediaList.add(file);
        } else if (mime != 'link') {
          docList.add(file);
        }
      }

      // 🔥 2. LINKS FROM MESSAGE TEXT
      final matches = regex.allMatches(msg.message);

      for (final m in matches) {
        final url = m.group(0);
        if (url != null) linkList.add(url);
      }
    }

    setState(() {
      media = mediaList;
      links = linkList.toList();
      docs = docList;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0052D4),
                  Color(0xFF4364F7),
                  Color(0xFF6FB1FC),
                ],
              ),
            ),
          ),
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          title: const Text(
            'Media & Assets',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Media'),
                    Tab(text: 'Links'),
                    Tab(text: 'Docs'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: _loading
            ? const WaitingLoading()
            : TabBarView(
                children: [_MediaTab(media), _LinksTab(links), _DocsTab(docs)],
              ),
      ),
    );
  }
}

class _MediaTab extends StatelessWidget {
  final List<FileModel> media;
  const _MediaTab(this.media);

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    if (media.isEmpty) {
      return _buildEmptyState(context, Iconsax.gallery, "No media shared yet");
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        interactive: true,
        trackVisibility: true,
        radius: const Radius.circular(8),
        thickness: 8,
        child: GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: media.length,
          itemBuilder: (_, index) {
            final file = media[index];

            final mime = (file.mimeType).toLowerCase();
            final ext = file.extension.toLowerCase();

            final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
            final isVideo =
                mime.startsWith('video/') || videoExtensions.contains(ext);

            return GestureDetector(
              onTap: () {
                if (isVideo) {
                  navigate.route(context, VideoPlay(file: file));
                } else {
                  navigate.route(
                    context,
                    GalleryScreen(images: media, initialIndex: index),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      /// IMAGE
                      if (!isVideo)
                        CachedNetworkImage(
                          imageUrl: file.url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            child: const Icon(Iconsax.gallery_slash),
                          ),
                        ),

                      /// VIDEO THUMBNAIL (Fallback UI)
                      if (isVideo)
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),

                      /// PLAY ICON OVERLAY (for video)
                      if (isVideo)
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LinksTab extends StatelessWidget {
  final List<String> links;
  const _LinksTab(this.links);

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    if (links.isEmpty) {
      return _buildEmptyState(context, Iconsax.link, "No links found in chat");
    }

    return Padding(
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
          padding: const EdgeInsets.all(16),
          itemCount: links.length,
          itemBuilder: (_, index) {
            final url = links[index];
            final domain = Uri.parse(url).host;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                onTap: () => launchUrl(Uri.parse(url)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.link_1,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    domain.isEmpty ? "External Link" : domain,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                trailing: Icon(
                  Iconsax.export_1,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DocsTab extends StatelessWidget {
  final List<FileModel> docs;
  const _DocsTab(this.docs);

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    if (docs.isEmpty) {
      return _buildEmptyState(
        context,
        Iconsax.document_text,
        "No documents attached",
      );
    }

    return Padding(
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
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final file = docs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.document_text,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  path.basename(file.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${file.size} KB • ${file.extension.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                trailing: Icon(
                  Iconsax.arrow_circle_down,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () async {
                  if (file.url.isEmpty) {
                    FlushBar.show(
                      context,
                      "Invalid file URL",
                      isSuccess: false,
                    );
                    return;
                  }
                  await Download.downloadWithLoading(context, file.url, file.name);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _buildEmptyState(BuildContext context, IconData icon, String message) {
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
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

extension MessagesExtensions on List<MessagesModel> {
  List<FileModel> media() {
    return expand((msg) => msg.attachments)
        .where(
          (f) =>
              f.mimeType.startsWith('image/') ||
              f.mimeType.startsWith('video/'),
        )
        .toList();
  }

  List<String> links() {
    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final List<String> result = [];
    for (final msg in this) {
      final matches = regex.allMatches(msg.message);
      for (final match in matches) {
        final url = match.group(0);
        if (url != null) result.add(url);
      }
    }
    return result;
  }

  List<FileModel> documents() {
    return expand((msg) => msg.attachments)
        .where(
          (f) =>
              !f.mimeType.startsWith('image/') &&
              !f.mimeType.startsWith('video/') &&
              f.mimeType != 'link',
        )
        .toList();
  }
}