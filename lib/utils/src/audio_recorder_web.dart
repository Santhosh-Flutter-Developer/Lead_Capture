// ─────────────────────────────────────────────────────────────────────────────
// audio_recorder_web.dart  — NEW FILE
// Web implementation — uses the browser's MediaRecorder API via dart:html.
// Only compiled on web via conditional import in audio_recorder.dart.
//
// The stopRecordingImpl() returns a temporary blob: URL that can be used as
// the audio source in an <audio> element or uploaded to Firebase Storage.
//
// To upload the recording to Firebase Storage on web:
//   final url = await AudioRecorder.stopRecording(); // blob: URL
//   final response = await http.get(Uri.parse(url));
//   await StorageService.uploadBytes(bytes: response.bodyBytes, fileName: 'audio.webm', folder: ...);
// ─────────────────────────────────────────────────────────────────────────────
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

html.MediaRecorder? _recorder;
html.MediaStream? _stream;
final List<html.Blob> _chunks = [];

Future<bool> requestMicPermissionImpl() async {
  try {
    _stream = await html.window.navigator.getUserMedia(audio: true);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> startRecordingImpl() async {
  final hasPermission = await requestMicPermissionImpl();
  if (!hasPermission) return;

  _chunks.clear();

  // Re-use the existing stream if available, otherwise request a new one
  _stream ??= await html.window.navigator.getUserMedia(audio: true);

  _recorder = html.MediaRecorder(_stream!);

  _recorder!.addEventListener('dataavailable', (event) {
    final blob = (event as html.BlobEvent).data;
    if (blob != null && blob.size > 0) {
      _chunks.add(blob);
    }
  });

  _recorder!.start();
}

Future<String?> stopRecordingImpl() async {
  if (_recorder == null) return null;

  final completer = Completer<String?>();

  _recorder!.addEventListener('stop', (_) {
    if (_chunks.isEmpty) {
      completer.complete(null);
      return;
    }
    final blob = html.Blob(_chunks, 'audio/webm');
    final url = html.Url.createObjectUrlFromBlob(blob);
    completer.complete(url); // Returns a blob: URL
  });

  _recorder!.stop();

  // Stop all tracks to release the microphone
  _stream?.getTracks().forEach((track) => track.stop());
  _stream = null;

  return completer.future;
}
