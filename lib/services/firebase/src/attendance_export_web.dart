// ─────────────────────────────────────────────────────────────────────────────
// attendance_export_web.dart  — NEW FILE
// Web download implementation for AttendanceExportService.
// Uses dart:html to trigger a browser <a download> click.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser download of [bytes] as [filename].
void webDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Not used on web — present only to satisfy the conditional import.
Future<void> nativeSaveAndOpen({
  required Uint8List bytes,
  required String filename,
}) async {
  throw UnsupportedError('nativeSaveAndOpen must not be called on web.');
}
