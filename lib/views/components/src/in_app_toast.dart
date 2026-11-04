import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Small, modern in-app notification that slides in from the TOP edge and
/// disappears by itself. Works for both web (wide) and mobile (narrow).
///
///  • Wide screens  -> compact card (max 380px) at the top-right corner.
///  • Narrow screens-> card with side margins, centred below the status bar.
///  • Tap the card   -> [onTap] (e.g. open the chat) and the toast closes.
///  • Swipe up / tap ✕ -> closes immediately.
///  • A new toast replaces the one that is currently visible.
class InAppToast {
  InAppToast._();

  /// How long the toast stays on screen. Change here to adjust globally.
  static const Duration displayDuration = Duration(seconds: 2);

  static OverlayEntry? _entry;
  static Timer? _timer;
  static _ToastController? _controller;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Iconsax.notification_bing,
    VoidCallback? onTap,
    OverlayState? overlay,
  }) {
    // Prefer the overlay passed in (e.g. navigatorKey.currentState?.overlay):
    // a Navigator's own context sits ABOVE its Overlay, so Overlay.of() on it
    // would find nothing.
    overlay ??= Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _removeNow();

    final controller = _ToastController();
    _controller = controller;

    _entry = OverlayEntry(
      builder: (_) => _ToastView(
        controller: controller,
        title: title,
        body: body,
        icon: icon,
        onTap: onTap,
        onClosed: _removeNow,
      ),
    );
    overlay.insert(_entry!);

    _timer = Timer(displayDuration, () => controller.close?.call());
  }

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _controller = null;
  }
}

class _ToastController {
  VoidCallback? close; // animates out, then calls onClosed
}

class _ToastView extends StatefulWidget {
  final _ToastController controller;
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onClosed;

  const _ToastView({
    required this.controller,
    required this.title,
    required this.body,
    required this.icon,
    required this.onClosed,
    this.onTap,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOut,
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.close = _close;
    _anim.forward();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _anim.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width >= 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF2A2D34) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    const accent = Color(0xFF2563EB);

    final card = Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onTap?.call();
          _close();
        },
        // Swipe up to dismiss.
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -150) _close();
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: bodyColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _close,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: bodyColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Positioned(
      top: mq.padding.top + 10,
      left: isWide ? null : 12,
      right: isWide ? 24 : 12,
      child: Align(
        alignment: isWide ? Alignment.topRight : Alignment.topCenter,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(opacity: _fade, child: card),
        ),
      ),
    );
  }
}