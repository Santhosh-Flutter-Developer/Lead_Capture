import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readBytesFromPath(String path) async {
  return File(path).readAsBytes();
}
