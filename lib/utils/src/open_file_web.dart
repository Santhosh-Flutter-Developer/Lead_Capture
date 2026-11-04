import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> platformLaunchFile({
  required List<int> bt,
  required String fn,
  required bool nf,
  String? name,
}) async {
  final blob = html.Blob([Uint8List.fromList(bt)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(const Duration(seconds: 30), () {
    html.Url.revokeObjectUrl(url);
  });
}

Future<String> platformSaveFile({
  required List<int> bt,
  required String fn,
}) async {
  final blob = html.Blob([Uint8List.fromList(bt)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fn)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return fn;
}

Future<void> platformOpenFile(String path) async {
  html.window.open(path, '_blank');
}
