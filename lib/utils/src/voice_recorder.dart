// ─────────────────────────────────────────────────────────────────────────────
// voice_recorder.dart
//
// WhatsApp-style voice-note recorder built on the `record` package.
//
// What it adds on top of the old static `AudioRecorder`:
//   • picks an encoder that actually works on the current platform
//       - Android / iOS / Windows / macOS / Safari  -> AAC-LC  (.m4a)
//       - Chrome / Firefox (web)                    -> WAV     (.wav)
//     (`aacLc` is NOT available in Chrome/Firefox MediaRecorder, and WebM/Opus
//      would not play back on iOS/Windows, so WAV is the safe web fallback.)
//   • live loudness samples, used to draw the waveform while recording and to
//     store a compact waveform with the finished message
//   • pause / resume / cancel and an accurate elapsed time (pauses excluded)
//
// Result of [stop]: a local file path on native platforms, or a `blob:` URL on
// web. The caller reads the bytes and uploads them.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;

import '/services/services.dart';

enum VoiceRecorderState { idle, starting, recording, paused }

class VoiceRecording {
  /// Local file path (native) or `blob:` URL (web).
  final String path;

  /// File extension without the dot: `m4a` or `wav`.
  final String extension;

  final Duration duration;

  /// ~[VoiceRecorder.waveformBars] loudness values in the range 0-100.
  final List<int> waveform;

  const VoiceRecording({
    required this.path,
    required this.extension,
    required this.duration,
    required this.waveform,
  });
}

class VoiceRecorder extends ChangeNotifier {
  /// Number of bars stored with a finished voice note.
  static const int waveformBars = 40;

  /// Number of bars kept for the live waveform shown while recording.
  static const int liveBars = 48;

  /// Recordings shorter than this are treated as accidental taps.
  static const Duration minDuration = Duration(seconds: 1);

  /// Safety cap so a forgotten recording can't grow forever.
  static const Duration maxDuration = Duration(minutes: 15);

  final rec.AudioRecorder _recorder = rec.AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();

  VoiceRecorderState _state = VoiceRecorderState.idle;
  StreamSubscription<rec.Amplitude>? _ampSub;
  Timer? _ticker;
  Future<bool>? _starting;
  String _extension = 'm4a';

  /// Every loudness sample (0.0-1.0) captured so far, ~10 per second.
  final List<double> _samples = [];

  /// Human readable reason when [start] returned false.
  String? lastError;

  VoiceRecorderState get state => _state;
  bool get isActive =>
      _state == VoiceRecorderState.recording ||
      _state == VoiceRecorderState.paused ||
      _state == VoiceRecorderState.starting;
  bool get isRecording => _state == VoiceRecorderState.recording;
  bool get isPaused => _state == VoiceRecorderState.paused;
  Duration get elapsed => _stopwatch.elapsed;

  /// Latest [liveBars] samples, oldest first (for the live waveform).
  List<double> get liveLevels {
    if (_samples.length <= liveBars) {
      return List<double>.filled(liveBars - _samples.length, 0) + _samples;
    }
    return _samples.sublist(_samples.length - liveBars);
  }

  // ── Encoder selection ─────────────────────────────────────────────────────

  Future<(rec.RecordConfig, String)> _pickConfig() async {
    try {
      if (await _recorder.isEncoderSupported(rec.AudioEncoder.aacLc)) {
        return (
          const rec.RecordConfig(
            encoder: rec.AudioEncoder.aacLc,
            bitRate: 64000,
            numChannels: 1,
          ),
          'm4a',
        );
      }
    } catch (_) {
      // fall through to WAV
    }
    // 16 kHz mono 16-bit WAV ≈ 1.9 MB per minute: plays everywhere.
    return (
      const rec.RecordConfig(
        encoder: rec.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      'wav',
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts recording. Returns false (and sets [lastError]) when the
  /// microphone is unavailable or permission was denied.
  Future<bool> start() {
    if (isActive) return _starting ?? Future.value(true);
    return _starting = _start().whenComplete(() => _starting = null);
  }

  Future<bool> _start() async {
    lastError = null;
    _setState(VoiceRecorderState.starting);
    try {
      if (!await _recorder.hasPermission()) {
        lastError =
            'Microphone permission denied. Please allow microphone access.';
        _setState(VoiceRecorderState.idle);
        return false;
      }

      final (config, ext) = await _pickConfig();
      _extension = ext;

      // On web `path` is ignored (the browser buffers the audio and exposes a
      // blob: URL on stop). Native platforms need a real file path.
      var path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      _samples.clear();
      _stopwatch
        ..reset()
        ..start();

      await _recorder.start(config, path: path);

      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(_onAmplitude, onError: (_) {});
      // Drives the elapsed-time label; the UI auto-stops via [reachedMax].
      _ticker = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => notifyListeners(),
      );

      _setState(VoiceRecorderState.recording);
      return true;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      lastError = 'Could not start recording.';
      await _teardown();
      return false;
    }
  }

  /// True once [maxDuration] has been reached.
  bool get reachedMax => _stopwatch.elapsed >= maxDuration;

  void _onAmplitude(rec.Amplitude amp) {
    if (_state != VoiceRecorderState.recording) return;
    // `current` is in dBFS (≈ -160 … 0). Voice sits roughly in -50 … -5.
    final db = amp.current.isFinite ? amp.current : -60.0;
    final level = ((db + 50) / 45).clamp(0.0, 1.0);
    _samples.add(level);
    notifyListeners();
  }

  Future<void> pause() async {
    if (_state != VoiceRecorderState.recording) return;
    try {
      await _recorder.pause();
      _stopwatch.stop();
      _setState(VoiceRecorderState.paused);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> resume() async {
    if (_state != VoiceRecorderState.paused) return;
    try {
      await _recorder.resume();
      _stopwatch.start();
      _setState(VoiceRecorderState.recording);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// Stops and returns the recording, or null when nothing usable was
  /// captured. Clips shorter than [minDuration] are discarded (null).
  Future<VoiceRecording?> stop() async {
    // The user may release the button before start() finished.
    if (_starting != null) await _starting;
    if (!isActive) return null;

    final duration = _stopwatch.elapsed;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
    final waveform = _buildWaveform();
    await _teardown();

    if (path == null || path.isEmpty || duration < minDuration) return null;

    return VoiceRecording(
      path: path,
      extension: _extension,
      duration: duration,
      waveform: waveform,
    );
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    if (_starting != null) await _starting;
    if (!isActive) return;
    try {
      await _recorder.cancel();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
    await _teardown();
  }

  Future<void> _teardown() async {
    await _ampSub?.cancel();
    _ampSub = null;
    _ticker?.cancel();
    _ticker = null;
    _stopwatch
      ..stop()
      ..reset();
    _samples.clear();
    _setState(VoiceRecorderState.idle);
  }

  /// Averages the raw samples into [waveformBars] buckets (0-100) and
  /// stretches them so a quiet recording still shows visible bars.
  List<int> _buildWaveform() {
    if (_samples.isEmpty) return List<int>.filled(waveformBars, 8);
    final out = <double>[];
    for (var i = 0; i < waveformBars; i++) {
      final start = (i * _samples.length / waveformBars).floor();
      var end = ((i + 1) * _samples.length / waveformBars).floor();
      if (end <= start) end = math.min(start + 1, _samples.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += _samples[j];
      }
      out.add(sum / (end - start));
    }
    final peak = out.reduce(math.max);
    final scale = peak > 0.05 ? 1 / peak : 1.0;
    return out
        .map((v) => (math.max(0.08, v * scale) * 100).round().clamp(8, 100))
        .toList();
  }

  void _setState(VoiceRecorderState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
