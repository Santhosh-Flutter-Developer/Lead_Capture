import 'dart:typed_data';

Future<Uint8List> readBytesFromPath(String path) async {
  throw UnsupportedError(
    'Cannot read file from path on web. Use PlatformFile.bytes instead.',
  );
}
