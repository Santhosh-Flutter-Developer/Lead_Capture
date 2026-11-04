// ─────────────────────────────────────────────────────────────────────────────
// notification_service_io.dart  — NEW FILE
// Used on native platforms (Android / iOS / Desktop) via conditional import.
// Contains filesystem-dependent avatar cache functions.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '/services/services.dart';

/// Downloads [url], crops it to a circle of [size]×[size] px, caches it in the
/// temp directory, and returns the local file path.
/// Returns null on any error or if the image cannot be fetched.
Future<String?> downloadAvatarCircular(
  String? url,
  String name, {
  int size = 192,
  Duration ttl = const Duration(days: 7),
  bool forceRefresh = false,
}) async {
  if (url == null || url.isEmpty) return null;
  try {
    final key = md5.convert(utf8.encode('$url|$name')).toString();
    final fileName = 'avatar_$key.png';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');

    if (!forceRefresh && await file.exists()) {
      try {
        final lastModified = await file.lastModified();
        if (DateTime.now().difference(lastModified) <= ttl) {
          return file.path;
        }
      } catch (_) {}
    }

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      if (await file.exists()) return file.path;
      return null;
    }

    final original = img.decodeImage(resp.bodyBytes);
    if (original == null) {
      if (await file.exists()) return file.path;
      return null;
    }

    final square = img.copyResizeCropSquare(original, size: size);
    final masked = img.Image(width: size, height: size, numChannels: 4);
    final double cx = (size - 1) / 2.0;
    final double cy = (size - 1) / 2.0;
    final double radius = size / 2.0;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (sqrt(dx * dx + dy * dy) <= radius) {
          masked.setPixel(x, y, square.getPixel(x, y));
        } else {
          masked.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    final pngBytes = img.encodePng(masked);
    await file.writeAsBytes(pngBytes, flush: true);
    return file.path;
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    debugPrint('downloadAvatarCircular error: $e\n$st');
    return null;
  }
}

/// Deletes all cached avatar PNG files from the temp directory.
Future<void> clearAvatarCacheNative() async {
  try {
    final dir = await getTemporaryDirectory();
    final files = Directory(dir.path).listSync();
    for (final f in files) {
      if (f is File &&
          f.path.endsWith('.png') &&
          f.path.contains('avatar_')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}

/// Not used outside web.
void listenForNotificationClicks(void Function(Map<String, dynamic>) onClick) {}

/// Web-only diagnostics; no-op elsewhere.
Future<void> diagnoseServiceWorker() async {}