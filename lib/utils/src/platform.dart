// ─────────────────────────────────────────────────────────────────────────────
// platform.dart  — web-safe platform detection
// CHANGED: removed `dart:io` import (crashes on web at compile time).
//          Now uses flutter/foundation.dart + kIsWeb + defaultTargetPlatform.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';

/// True only on real Android/iOS devices (never on web).
bool get kIsMobile {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// True on Windows / Linux / macOS native (never on web).
bool get kIsDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// True only on native Windows.
bool get kIsWindows {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows;
}
