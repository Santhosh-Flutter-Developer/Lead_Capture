import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/models.dart';
import '/views/views.dart';
import 'download.dart';
import 'routes.dart';

const List<String> _imageExtensions = [
  "png",
  "jpg",
  "jpeg",
  "webp",
  "bmp",
  "gif",
  "tiff",
];
const List<String> _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
const List<String> _audioExtensions = ['mp3', 'wav', 'aac'];
// Plain-text formats every browser can render directly when navigated to —
// no CORS-sensitive byte fetch involved, unlike images/PDF rendered inside
// the Flutter app itself.
const List<String> _textExtensions = ['csv', 'txt', 'json', 'xml', 'htm', 'html'];

/// Opens/previews an already-saved attachment. This should only ever be
/// wired up for attachments that already exist on the server (i.e. after a
/// save) — files a user has just picked but not yet uploaded should not be
/// tappable at all.
///
/// There is deliberately no separate "download" action anywhere in the app:
/// each viewer below (image gallery, PDF viewer, video/audio player) has its
/// own built-in download button, and file types with no in-app or browser
/// viewer are downloaded automatically instead of opened.
///
/// Word/Excel/PowerPoint files are downloaded rather than opened in a
/// browser-based viewer: both Google Docs Viewer and Microsoft's Office
/// Online Viewer turned out to be unreliable at fetching Firebase Storage's
/// long, token-based URLs (a known compatibility gap, not something fixable
/// from the app side), so a guaranteed download is more dependable than an
/// external viewer that may silently fail.
Future<void> previewAttachment(BuildContext context, FileModel file) async {
  if (file.url.isEmpty) {
    FlushBar.show(context, 'File URL is unavailable', isSuccess: false);
    return;
  }

  final mime = file.mimeType.toLowerCase();
  final ext = file.extension.toLowerCase();

  final isImage = mime.startsWith('image/') || _imageExtensions.contains(ext);
  final isVideo = mime.startsWith('video/') || _videoExtensions.contains(ext);
  final isAudio = mime.startsWith('audio/') || _audioExtensions.contains(ext);
  final isPdf = ext == 'pdf';
  final isText = _textExtensions.contains(ext);

  // CSV/TXT/JSON/etc. are rendered directly by the browser (and by most
  // native default-app handlers) with a plain navigation — no server-side
  // viewer and no CORS-sensitive byte fetch needed, so this is safe on
  // every platform regardless of storage bucket CORS configuration.
  if (isText) {
    await openAttachmentExternally(context, file);
    return;
  }

  if (kIsWeb) {
    // Browsers render images/PDF/video/audio natively when navigated to
    // directly, so opening externally is enough and avoids the CORS
    // restrictions that fetching bytes via XHR would run into.
    if (isImage || isVideo || isAudio || isPdf) {
      await openAttachmentExternally(context, file);
      return;
    }
  } else {
    if (isImage) {
      Navigate.route(context, GalleryScreen(images: [file], initialIndex: 0));
      return;
    } else if (isVideo) {
      Navigate.route(context, VideoPlay(file: file));
      return;
    } else if (isAudio) {
      Navigate.route(context, AudioPlay(file: file));
      return;
    } else if (isPdf) {
      Navigate.route(context, PdfPreviewPage(file: file));
      return;
    }
  }

  // Office documents and anything else with no reliable in-app or browser
  // viewer are downloaded automatically instead of opened.
  await Download.downloadFromUrl(context, file.url, file.name);
}

/// Opens the attachment's raw URL in the browser (web) or the platform's
/// default external app (native).
Future<void> openAttachmentExternally(
  BuildContext context,
  FileModel file,
) async {
  if (file.url.isEmpty) {
    FlushBar.show(context, 'File URL is unavailable', isSuccess: false);
    return;
  }
  final uri = Uri.tryParse(file.url);
  final launched =
      uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    FlushBar.show(context, 'Could not open file', isSuccess: false);
  }
}
