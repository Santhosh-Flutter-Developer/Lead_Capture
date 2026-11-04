import 'dart:typed_data';
import '/utils/src/open_file.dart';

/// Not used on native — present only to satisfy the conditional import.
void webDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError('webDownloadFile must not be called on native.');
}

/// Saves [bytes] to the platform downloads directory and opens the file.
Future<void> nativeSaveAndOpen({
  required Uint8List bytes,
  required String filename,
}) async {
  await FileHelper.saveFile(bt: bytes.toList(), fn: filename);
}