// download_web.dart — web browser download implementation
// Only compiled on web (conditional import in download.dart).
// Uses dart:html Blob + <a download> click to push bytes to the browser.
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser file download of [bytes] with the given [fileName].
/// Returns [fileName] as the pseudo-path (browsers have no real filesystem path).
Future<String> saveFileToDownloads(Uint8List bytes, {String? fileName}) async {
  final name = (fileName == null || fileName.isEmpty) ? 'download' : fileName;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return name;
}

/// No-op on web — _NativeUrlDownloader.run() is never called because
/// download.dart checks kIsWeb before calling it.
Future<void> runNativeUrlDownload(
    dynamic context, String url, String? name) async {
  throw UnsupportedError('_runNativeUrlDownload must not be called on web.');
}
