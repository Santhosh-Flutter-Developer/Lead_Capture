part of 'chat_messages.dart';

// ─────────────────────────────────────────────────────────────────
// WhatsApp-style voice message (playback + shared waveform painter)
// ─────────────────────────────────────────────────────────────────
//
// Rendered inline in the chat for attachments flagged `isVoice`:
//   [▶]  ▂▃▅▇▅▃▂▃▅▇▅▃▂  0:07   [1x]
// * tap play/pause, tap or drag the waveform to seek
// * speed chip cycles 1x → 1.5x → 2x
// * only one voice message plays at a time
// * the player is created lazily on first tap, so long chat histories
//   with many voice notes don't allocate a native player per message

/// True on phones/tablets (including mobile browsers) where press-and-hold
/// is the natural way to record. Mouse platforms use click-to-record.
bool _isTouchPlatform() {
  if (kIsMobile) return true;
  return kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

String _formatVoiceDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Draws vertical rounded bars. Bars up to [progress] (0-1) use [activeColor].
class _WaveformPainter extends CustomPainter {
  final List<double> levels; // 0.0 - 1.0
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _WaveformPainter({
    required this.levels,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0) return;
    const barWidth = 3.0;
    const minBar = 3.0;
    final slot = size.width / levels.length;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < levels.length; i++) {
      final h = (levels[i].clamp(0.0, 1.0) * size.height).clamp(
        minBar,
        size.height,
      );
      final x = slot * i + slot / 2;
      final isActive = (i + 0.5) / levels.length <= progress;
      paint
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      !listEquals(old.levels, levels);
}

class VoiceMessagePlayer extends StatefulWidget {
  final FileModel file;
  final bool isSender;

  const VoiceMessagePlayer({
    super.key,
    required this.file,
    this.isSender = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  /// The voice message that is currently playing (so we can stop it when
  /// another one starts).
  static _VoiceMessagePlayerState? _current;

  AudioPlayer? _player;
  final List<StreamSubscription> _subs = [];

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasStarted = false;
  // True when the player has no loaded source (first play, after the clip
  // finished — audioplayers releases it — or after an error). Then the next
  // tap must call play(UrlSource) again; resume() would fail.
  bool _needsSource = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _rate = 1.0;

  late final List<double> _levels = _initLevels();

  List<double> _initLevels() {
    if (widget.file.waveform.isNotEmpty) {
      return widget.file.waveform.map((e) => (e / 100).clamp(0.0, 1.0)).toList();
    }
    // Older / imported audio has no stored waveform: draw a stable pattern.
    final seed = widget.file.url.hashCode;
    return List<double>.generate(
      40,
      (i) => 0.25 + 0.6 * (((seed >> (i % 24)) + i * 7) % 10) / 10,
    );
  }

  Duration get _total {
    if (_duration > Duration.zero) return _duration;
    return Duration(milliseconds: widget.file.durationMs);
  }

  double get _progress {
    final total = _total.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    // Keep the source after the clip ends so it can be replayed.
    p.setReleaseMode(ReleaseMode.stop);
    _player = p;
    _subs.addAll([
      p.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
      p.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _duration = d);
      }),
      p.onPlayerStateChanged.listen((s) {
        if (!mounted) return;
        setState(() {
          _isPlaying = s == PlayerState.playing;
          if (s == PlayerState.playing) _isLoading = false;
        });
      }),
      p.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isLoading = false;
          _position = Duration.zero;
          _needsSource = true; // replay must load the source again
        });
        if (_current == this) _current = null;
      }),
    ]);
    return p;
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player?.pause();
      return;
    }
    await _playFrom(_position);
  }

  Future<void> _playFrom(Duration start) async {
    // Stop whichever voice message was playing before.
    final other = _current;
    if (other != null && other != this) await other._stopPlayback();
    _current = this;

    final player = _ensurePlayer();
    setState(() => _isLoading = _needsSource);
    try {
      if (_needsSource) {
        await _playFresh(player, start);
      } else {
        try {
          await player.seek(start);
          await player.resume();
        } catch (_) {
          // Player lost its source (state error): load it again.
          await _playFresh(player, start);
        }
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      // Throw the broken native player away; the next tap builds a new one.
      await _discardPlayer();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });
        FlushBar.show(context, 'Could not play voice message', isSuccess: false);
      }
    }
  }

  Future<void> _playFresh(AudioPlayer player, Duration start) async {
    await player.setPlaybackRate(_rate);
    await player.play(UrlSource(widget.file.url), position: start);
    _hasStarted = true;
    _needsSource = false;
  }

  Future<void> _discardPlayer() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = _player;
    _player = null;
    _needsSource = true;
    try {
      await p?.dispose();
    } catch (_) {}
  }

  Future<void> _stopPlayback() async {
    try {
      await _player?.pause();
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _seekToFraction(double fraction) async {
    final total = _total;
    if (total <= Duration.zero) return;
    final target = Duration(
      milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    setState(() => _position = target);
    if (_hasStarted) {
      await _player?.seek(target);
    }
  }

  Future<void> _cycleSpeed() async {
    final next = _rate == 1.0 ? 1.5 : (_rate == 1.5 ? 2.0 : 1.0);
    setState(() => _rate = next);
    try {
      await _player?.setPlaybackRate(next);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_current == this) _current = null;
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = widget.isSender
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final active = cs.primary;
    final inactive = cs.onSurfaceVariant.withValues(alpha: 0.35);

    final showElapsed = _isPlaying || (_hasStarted && _position > Duration.zero);
    final label = _formatVoiceDuration(showElapsed ? _position : _total);

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: active,
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                    style: IconButton.styleFrom(
                      backgroundColor: active,
                      foregroundColor: cs.onPrimary,
                    ),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    onPressed: _toggle,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final width = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _seekToFraction(d.localPosition.dx / width),
                      onHorizontalDragUpdate: (d) =>
                          _seekToFraction(d.localPosition.dx / width),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SizedBox(
                          height: 28,
                          width: width,
                          child: CustomPaint(
                            painter: _WaveformPainter(
                              levels: _levels,
                              progress: _progress,
                              activeColor: active,
                              inactiveColor: inactive,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (_hasStarted) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _cycleSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _rate == 1.0 ? '1x' : '${_rate}x',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}