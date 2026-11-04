// ─────────────────────────────────────────────────────────────────────────────
// audio_recorder_io.dart  — NEW FILE
// Native implementation — uses MethodChannel + permission_handler.
// Only compiled on native via conditional import in audio_recorder.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '/services/services.dart';

const _channel = MethodChannel('com.srisoftwarez.audio_recorder');

Future<bool> requestMicPermissionImpl() async {
  try {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    return false;
  }
}

Future<void> startRecordingImpl() async {
  if (await requestMicPermissionImpl()) {
    await _channel.invokeMethod('startRecording');
  }
}

Future<String?> stopRecordingImpl() async {
  final String? path = await _channel.invokeMethod('stopRecording');
  return path;
}
