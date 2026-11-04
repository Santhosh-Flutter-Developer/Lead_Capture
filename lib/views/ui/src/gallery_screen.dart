import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/views/views.dart';

/// A full-screen image gallery viewer.
class GalleryScreen extends StatefulWidget {
  final List<FileModel> images;
  final int initialIndex;

  const GalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _index = widget.initialIndex; // initialize current index
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 16;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(
                    Iconsax.close_circle,
                    color: AppColors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.images[_index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        "${(widget.images[_index].size / 1000000).toStringAsFixed(2)} MB",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall!.copyWith(color: AppColors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "${_index + 1} / ${widget.images.length}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: AppColors.white),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.white,
                  ),
                  onPressed: () => Download.downloadWithLoading(
                    context,
                    widget.images[_index].url,
                    widget.images[_index].name,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PhotoViewGallery.builder(
              pageController: _controller,
              itemCount: widget.images.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                    widget.images[index].url,
                  ),
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: widget.images[index].url,
                  ),
                );
              },
              backgroundDecoration: const BoxDecoration(color: AppColors.black),
              onPageChanged: (newIndex) {
                setState(() {
                  _index = newIndex;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}