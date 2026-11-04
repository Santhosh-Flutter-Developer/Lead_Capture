// ─────────────────────────────────────────────────────────────────────────────
// audio_recorder.dart
// CHANGED: The previous implementation called a custom native MethodChannel
// ('com.srisoftwarez.audio_recorder') via audio_recorder_io.dart, but no
// native handler for that channel was ever registered on Android, iOS,
// Windows, macOS, or Linux (confirmed by inspecting MainActivity.kt,
// AppDelegate.swift, and flutter_window.cpp) — so recording silently failed
// with a MissingPluginException on every native platform. The web
// implementation (audio_recorder_web.dart) worked, but its output was never
// actually uploaded (see input_bar.dart's old "Web blob URL audio upload not
// supported yet — skip silently" branch).
//
// Replaced both with the `record` package (pub.dev/packages/record), which
// ships real, maintained native implementations for every platform this app
// targets: Android (AudioRecord/MediaCodec), iOS/macOS (AVFoundation),
// Windows (MediaFoundation), Linux (parecord/ffmpeg), and Web
// (MediaRecorder). This removes the need for a custom platform channel and
// for separate io/web conditional-import files entirely.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;
import '/services/services.dart';

class AudioRecorder {
  static final rec.AudioRecorder _recorder = rec.AudioRecorder();

  /// Requests microphone permission.
  /// - Native (Android/iOS/macOS/Windows/Linux): system permission prompt.
  /// - Web: browser getUserMedia prompt.
  static Future<bool> requestMicPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return false;
    }
  }

  /// Starts audio recording.
  static Future<void> startRecording() async {
    try {
      if (!await requestMicPermission()) return;

      // On web, `path` is ignored by the package (recording is buffered
      // in-memory by the browser and only exposed as a blob: URL on stop).
      // On native platforms a real file path is required up front.
      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(
        const rec.RecordConfig(encoder: rec.AudioEncoder.aacLc),
        path: path,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// Stops recording.
  /// Returns a local file path (native) or a browser `blob:` URL (web),
  /// or null if nothing was recorded.
  static Future<String?> stopRecording() async {
    try {
      return await _recorder.stop();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  /// True while actively recording.
  static Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  /// Releases recorder resources. Call when the recorder is no longer needed
  /// (e.g. app/chat screen teardown), not after every single recording.
  static Future<void> dispose() async {
    await _recorder.dispose();
  }
}
